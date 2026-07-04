import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/runtime/animation_plan_adapter.dart';
import 'package:fluvie/src/composition/timeline_label.dart';
import 'package:fluvie/src/composition/timeline_placement.dart';
import 'package:fluvie/src/composition/timeline_schedule.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/timing/placement/effective_duration.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:meta/meta.dart';

export 'package:fluvie/src/composition/timeline_placement.dart' show TimelinePlacement;

/// An opt-in, GSAP-style timeline that places animations on one shared clock —
/// the real implementation of the [TimelineSchedule] contract `Scene.sequence`
/// consumes.
///
/// `Timeline` is a mutable builder: each [play]/[playAll]/[wait]/[label]
/// records a step against a running playhead, resolved to absolute frames at
/// [fps]. The resulting [placements] are what a `Scene.sequence` binds to its
/// anchored children, and [duration] — the end of the latest step — is the
/// length the scene adopts. Beginners never need it; the per-element
/// `.animate()` API covers the easy ninety percent.
///
/// ```dart
/// final tl = Timeline(defaults: const Defaults(duration: Time.seconds(0.5)))
///   ..play(title, Animation.from(const Keyframe(y: 1)))
///   ..play(subtitle, Animation.fadeIn(), at: Trigger.whenEnds(title))
///   ..wait(0.3.seconds)
///   ..playAll(bullets, Animation.from(const Keyframe(x: -0.3)), stagger: 0.08.seconds)
///   ..label('reveal')
///   ..play(cta, Animation.pop(), at: 'reveal'.label - 0.2.seconds);
/// ```
///
/// Times resolve against [fps] (the playhead is the relative window), so build a
/// timeline at the same fps as its `Video`. `at:` accepts a [Trigger]
/// (`Trigger.at`/`after`/`previous`/`auto`), a `String` label, or a [LabelRef]
/// with offset arithmetic.
@experimental
final class Timeline implements TimelineSchedule {
  /// Creates an empty timeline resolving at [fps], with optional [defaults]
  /// filling each step's unset duration/ease.
  Timeline({this.fps = 30, Defaults? defaults}) : _merged = mergeDefaultsChain(video: defaults);

  /// The frame rate every recorded [Time] resolves against — match the `Video`.
  final int fps;

  final Defaults _merged;
  final List<TimelinePlacement> _placements = [];
  final Map<Anchor, int> _endByAnchor = {};
  final Map<String, int> _labels = {};
  int _playhead = 0;
  int _previousEnd = 0;

  /// The resolved placement plan: one entry per played target, in record order,
  /// each carrying its target anchor, animation, and absolute start.
  List<TimelinePlacement> get placements => List.unmodifiable(_placements);

  @override
  Time get duration {
    var end = 0;
    for (final placement in _placements) {
      final candidate = placement.startFrame + placement.durationFrames;
      if (candidate > end) end = candidate;
    }
    return Time.frames(end);
  }

  /// Plays [animation] on [target], starting at [at] (default: the playhead),
  /// then advances the playhead to the step's end.
  void play(Anchor target, Animation animation, {Object? at}) {
    final start = _resolveStart(at) + animation.delay.resolveFrames(_scope);
    _record(target, animation, start);
    final end = start + _durationOf(animation);
    _playhead = end;
    _previousEnd = end;
  }

  /// Plays [animation] on every target in [targets], staggered by [stagger]
  /// (default: all together), starting at [at] (default: the playhead), then
  /// advances the playhead to the latest target's end.
  void playAll(Iterable<Anchor> targets, Animation animation, {Object? at, Time? stagger}) {
    final base = _resolveStart(at) + animation.delay.resolveFrames(_scope);
    final gap = stagger?.resolveFrames(_scope) ?? 0;
    final duration = _durationOf(animation);
    var unionEnd = base;
    var index = 0;
    for (final target in targets) {
      final start = base + index * gap;
      _record(target, animation, start);
      final end = start + duration;
      if (end > unionEnd) unionEnd = end;
      index++;
    }
    _playhead = unionEnd;
    _previousEnd = unionEnd;
  }

  /// Advances the playhead by [gap] without recording a step.
  void wait(Time gap) => _playhead += gap.resolveFrames(_scope);

  /// Records the current playhead under [name] so later steps can place
  /// themselves relative to it via `at: 'name'.label`.
  void label(String name) => _labels[name] = _playhead;

  /// Records a placement and tracks the per-anchor end for `Trigger.whenEnds`.
  void _record(Anchor target, Animation animation, int start) {
    final placement = TimelinePlacement(
      target: target,
      animation: animation,
      start: Time.frames(start),
      durationFrames: _durationOf(animation),
    );
    _placements.add(placement);
    final end = start + placement.durationFrames;
    final existing = _endByAnchor[target];
    if (existing == null || end > existing) _endByAnchor[target] = end;
  }

  /// The resolved frame duration of [animation] under the merged defaults.
  int _durationOf(Animation animation) =>
      effectiveDurationFrames(toAnimationPlan(animation), _merged, _scope);

  /// Resolves an `at:` argument to an absolute start frame.
  ///
  /// `null` and [Trigger.auto] mean the current playhead; [Trigger.previous]
  /// the previous step's end; [Trigger.whenEnds] the named anchor's end;
  /// [AbsoluteTrigger] an absolute time; a `String`/[LabelRef] a label
  /// position with optional offset.
  int _resolveStart(Object? at) => switch (at) {
    null || AutoTrigger() => _playhead,
    PreviousTrigger() => _previousEnd,
    final AbsoluteTrigger trigger => trigger.time.resolveFrames(_scope),
    final WhenEndsTrigger trigger => _endByAnchor[trigger.anchor] ?? _playhead,
    final WhenStartsTrigger trigger => _startOf(trigger.anchor),
    final String name => _labelPosition(name, Time.zero),
    final LabelRef ref => _labelPosition(ref.name, ref.offset),
    _ => throw ArgumentError.value(
      at,
      'at',
      'Timeline.at: accepts a Trigger, a String label, or a LabelRef',
    ),
  };

  /// The recorded start of the earliest step on [anchor], for `whenStarts`.
  int _startOf(Anchor anchor) {
    for (final placement in _placements) {
      if (identical(placement.target, anchor)) return placement.startFrame;
    }
    return _playhead;
  }

  /// The frame of label [name] plus [offset], throwing when [name] is unknown.
  int _labelPosition(String name, Time offset) {
    final position = _labels[name];
    if (position == null) {
      throw ArgumentError.value(name, 'at', 'No timeline label named "$name" has been recorded');
    }
    return position + offset.resolveFrames(_scope);
  }

  /// The scope every [Time] resolves against: the timeline's fps with the
  /// playhead as the relative window.
  TimeScopeData get _scope => TimeScopeData(fps: fps, startFrame: 0, durationFrames: _playhead);
}
