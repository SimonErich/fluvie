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

part 'timeline_steps.dart';

/// An opt-in, GSAP-style timeline that places animations on one shared clock —
/// the real implementation of the [TimelineSchedule] contract `Scene.sequence`
/// consumes.
///
/// `Timeline` is a mutable builder: each [play]/[playAll]/[wait]/[label]
/// records a step against a running playhead. The steps stay symbolic — they
/// resolve to absolute frames only when the enclosing `Video`'s fps is known,
/// so the same timeline places identically whether the video runs at 30 or
/// 60 fps ([placementsAt] runs the resolution; [duration] defers it through a
/// scope-computed [Time]). Beginners never need it; the per-element
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
/// `at:` accepts a [Trigger] (`Trigger.at`/`whenEnds`/`previous`/`auto`), a
/// `String` label, or a [LabelRef] with offset arithmetic.
@experimental
final class Timeline implements TimelineSchedule {
  /// Creates an empty timeline with optional [defaults] filling each step's
  /// unset duration/ease. Times resolve at the enclosing `Video`'s fps.
  Timeline({Defaults? defaults}) : _merged = mergeDefaultsChain(video: defaults);

  final Defaults _merged;
  final List<_TimelineStep> _steps = [];
  final Map<int, _Resolution> _resolutions = {};
  final Set<String> _labelNames = {};

  /// The fps-independent shape of the plan: one entry per played target, in
  /// record order (a [playAll] expands to one entry per target), pairing the
  /// target anchor with its animation. The binder groups children by these and
  /// defers each start to [startFrameAt] — the entry's index here matches its
  /// placement's index in [placementsAt].
  List<({Anchor target, Animation animation})> get placementRefs => List.unmodifiable([
    for (final step in _steps)
      ...switch (step) {
        final _PlayStep s => [(target: s.target, animation: s.animation)],
        final _PlayAllStep s => [for (final t in s.targets) (target: t, animation: s.animation)],
        _ => const <({Anchor target, Animation animation})>[],
      },
  ]);

  /// The resolved placement plan at [fps]: one entry per played target, in
  /// record order, each carrying its target anchor, animation, and absolute
  /// start. Memoized per fps; recording another step invalidates the cache.
  List<TimelinePlacement> placementsAt(int fps) => _resolutionFor(fps).placements;

  /// The absolute start frame of placement [index] at [fps] — the binder's
  /// per-placement lookup behind a scope-computed `Trigger.at`.
  int startFrameAt(int fps, int index) => _resolutionFor(fps).placements[index].startFrame;

  /// The schedule's total length: the end of the latest step, resolved at the
  /// consuming scope's fps (the enclosing `Video`'s clock).
  @override
  Time get duration => ComputedTime((scope) => _resolutionFor(scope.fps).totalFrames);

  /// Plays [animation] on [target], starting at [at] (default: the playhead),
  /// then advances the playhead to the step's end.
  void play(Anchor target, Animation animation, {Object? at}) {
    _validateAt(at);
    _steps.add(_PlayStep(target, animation, at));
    _resolutions.clear();
  }

  /// Plays [animation] on every target in [targets], staggered by [stagger]
  /// (default: all together), starting at [at] (default: the playhead), then
  /// advances the playhead to the latest target's end.
  void playAll(Iterable<Anchor> targets, Animation animation, {Object? at, Time? stagger}) {
    _validateAt(at);
    _steps.add(_PlayAllStep(List.unmodifiable(targets), animation, at, stagger));
    _resolutions.clear();
  }

  /// Advances the playhead by [gap] without recording a placement.
  void wait(Time gap) {
    _steps.add(_WaitStep(gap));
    _resolutions.clear();
  }

  /// Records the current playhead under [name] so later steps can place
  /// themselves relative to it via `at: 'name'.label`.
  void label(String name) {
    _labelNames.add(name);
    _steps.add(_LabelStep(name));
    _resolutions.clear();
  }

  /// Rejects a malformed `at:` at record time, so authoring mistakes surface
  /// on the builder call rather than at the first fps resolution.
  void _validateAt(Object? at) {
    switch (at) {
      case null || Trigger():
        return;
      case final String name when _labelNames.contains(name):
        return;
      case final LabelRef ref when _labelNames.contains(ref.name):
        return;
      case final String name:
        throw ArgumentError.value(
          name,
          'at',
          'No timeline label named "$name" has been recorded',
        );
      case final LabelRef ref:
        throw ArgumentError.value(
          ref.name,
          'at',
          'No timeline label named "${ref.name}" has been recorded',
        );
      default:
        throw ArgumentError.value(
          at,
          'at',
          'Timeline.at: accepts a Trigger, a String label, or a LabelRef',
        );
    }
  }

  _Resolution _resolutionFor(int fps) =>
      _resolutions.putIfAbsent(fps, () => _Resolution.run(_steps, _merged, fps));
}
