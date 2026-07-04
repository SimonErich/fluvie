part of 'timeline.dart';

/// One recorded builder call, kept symbolic so the plan can resolve at any
/// fps. The variants mirror the four builder methods.
sealed class _TimelineStep {
  const _TimelineStep();
}

final class _PlayStep extends _TimelineStep {
  const _PlayStep(this.target, this.animation, this.at);
  final Anchor target;
  final Animation animation;
  final Object? at;
}

final class _PlayAllStep extends _TimelineStep {
  const _PlayAllStep(this.targets, this.animation, this.at, this.stagger);
  final List<Anchor> targets;
  final Animation animation;
  final Object? at;
  final Time? stagger;
}

final class _WaitStep extends _TimelineStep {
  const _WaitStep(this.gap);
  final Time gap;
}

final class _LabelStep extends _TimelineStep {
  const _LabelStep(this.name);
  final String name;
}

/// The playhead algorithm run over the recorded steps at one [fps]: the same
/// sequential walk the mutable builder used to do eagerly, now replayable so
/// each fps gets its own absolute frames.
final class _Resolution {
  _Resolution._(this.placements, this.totalFrames);

  factory _Resolution.run(List<_TimelineStep> steps, Defaults merged, int fps) {
    final run = _ResolutionRun(merged, fps);
    for (final step in steps) {
      switch (step) {
        case final _PlayStep s:
          run.play(s.target, s.animation, s.at);
        case final _PlayAllStep s:
          run.playAll(s.targets, s.animation, s.at, s.stagger);
        case final _WaitStep s:
          run.wait(s.gap);
        case final _LabelStep s:
          run.label(s.name);
      }
    }
    return _Resolution._(List.unmodifiable(run.placements), run.totalFrames);
  }

  final List<TimelinePlacement> placements;
  final int totalFrames;
}

/// The mutable state of one resolution walk.
final class _ResolutionRun {
  _ResolutionRun(this._merged, this.fps);

  final Defaults _merged;
  final int fps;
  final List<TimelinePlacement> placements = [];
  final Map<Anchor, int> _endByAnchor = {};
  final Map<String, int> _labels = {};
  int _playhead = 0;
  int _previousEnd = 0;

  int get totalFrames {
    var end = 0;
    for (final placement in placements) {
      final candidate = placement.startFrame + placement.durationFrames;
      if (candidate > end) end = candidate;
    }
    return end;
  }

  void play(Anchor target, Animation animation, Object? at) {
    final start = _resolveStart(at) + animation.delay.resolveFrames(_scope);
    _record(target, animation, start);
    final end = start + _durationOf(animation);
    _playhead = end;
    _previousEnd = end;
  }

  void playAll(List<Anchor> targets, Animation animation, Object? at, Time? stagger) {
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

  void wait(Time gap) => _playhead += gap.resolveFrames(_scope);

  void label(String name) => _labels[name] = _playhead;

  /// Records a placement and tracks the per-anchor end for `Trigger.whenEnds`.
  void _record(Anchor target, Animation animation, int start) {
    final placement = TimelinePlacement(
      target: target,
      animation: animation,
      start: Time.frames(start),
      durationFrames: _durationOf(animation),
    );
    placements.add(placement);
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
    for (final placement in placements) {
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

  /// The scope every [Time] resolves against: the resolving fps with the
  /// playhead as the relative window.
  TimeScopeData get _scope => TimeScopeData(fps: fps, startFrame: 0, durationFrames: _playhead);
}
