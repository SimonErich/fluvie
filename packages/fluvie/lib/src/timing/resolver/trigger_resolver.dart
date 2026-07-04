import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/timing/placement/placement.dart';
import 'package:fluvie/src/timing/plan/composition_plan.dart';
import 'package:fluvie/src/timing/plan/element_plan.dart';
import 'package:fluvie/src/timing/resolver/anchor_registry.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:meta/meta.dart';

/// An absolute, resolved animation span in video frames: [start] inclusive,
/// [end] exclusive — the resolver's output currency.
@immutable
final class ResolvedSpan {
  /// Creates a span running from frame [start] to frame [end].
  const ResolvedSpan(this.start, this.end);

  /// The first frame of the span (inclusive).
  final int start;

  /// The frame the span ends on (exclusive).
  final int end;

  @override
  bool operator ==(Object other) =>
      other is ResolvedSpan && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(ResolvedSpan, start, end);

  @override
  String toString() => 'ResolvedSpan($start..$end)';
}

/// The resolve pass of the two-pass trigger resolver: turns one node's
/// [Trigger] into an absolute [ResolvedSpan], given everything the caller
/// already resolved (window, duration, delay).
///
/// The caller walks nodes in topological order, writing each result into the
/// shared `resolved` map before moving on — [anchorTimeline] reads that map.
/// Anchoring: only `Trigger.auto` exits and `Trigger.sceneEnd` are
/// end-anchored; every other trigger starts at `triggerFrame + delay`, and a
/// `during` animation keeps running to its window end whatever started it.
final class TriggerResolver {
  /// Creates a resolver over `plan`; `resolved` and `windows` are read live,
  /// so the caller may keep filling `resolved` between [resolve] calls.
  TriggerResolver({
    required this._plan,
    required this._registry,
    required this._resolved,
    required this._windows,
  });

  final CompositionPlan _plan;
  final AnchorRegistry _registry;
  final Map<int, ResolvedSpan> _resolved;
  final Map<ElementPlan, ResolvedSpan> _windows;

  /// Resolves [node] to absolute frames.
  ///
  /// [elementScope] must come from `elementScopeFor`: the scene scope itself
  /// for a window-less element, or a direct child of it otherwise — that is
  /// how `sceneStart`/`sceneEnd` find the scene. [window] is the element's
  /// resolved window, [durationFrames] the effective duration, and
  /// [delayFrames] the delay already resolved against the nearest scope.
  ///
  /// This is raw placement math: spans may overhang the window or scene;
  /// bounds checks become warnings during composition resolution.
  ResolvedSpan resolve({
    required AnimationNode node,
    required TimeScopeData elementScope,
    required ResolvedSpan window,
    required int durationFrames,
    required int delayFrames,
  }) {
    final phase = node.plan.phase;
    ResolvedSpan startAnchored(int triggerFrame) {
      final start = triggerFrame + delayFrames;
      final end = phase == AnimationPhase.during ? window.end : start + durationFrames;
      return ResolvedSpan(start, end);
    }

    return switch (node.plan.at) {
      AutoTrigger() => _placed(phase, window, durationFrames, delayFrames),
      SceneStartTrigger() => startAnchored(_sceneScope(node, elementScope).startFrame),
      SceneEndTrigger() => _endAnchored(
        _sceneScope(node, elementScope).endFrame,
        durationFrames,
        delayFrames,
      ),
      AbsoluteTrigger(:final time) => startAnchored(
        elementScope.startFrame + time.resolveFrames(elementScope),
      ),
      PreviousTrigger() => startAnchored(_previousEnd(node)),
      WhenEndsTrigger(:final anchor) => startAnchored(anchorTimeline(anchor).end),
      WhenStartsTrigger(:final anchor) => startAnchored(anchorTimeline(anchor).start),
      final BeatTrigger beat => startAnchored(_beatFrame(beat, node, window)),
    };
  }

  /// The anchored element's timeline: the union span `[min start, max
  /// end]` of its already-resolved animations, or its window when it declares
  /// none. `after` chains off the union end; `whenStarts` off the start.
  ResolvedSpan anchorTimeline(Anchor anchor) {
    final nodes = _registry.nodesForAnchor(anchor);
    if (nodes.isEmpty) {
      final window = _windows[_registry.elementForAnchor(anchor)];
      if (window == null) {
        throw StateError("No resolved window for $anchor's element — pass it in `windows`.");
      }
      return window;
    }
    var start = _spanOf(nodes.first).start;
    var end = _spanOf(nodes.first).end;
    for (final node in nodes.skip(1)) {
      final span = _spanOf(node);
      if (span.start < start) start = span.start;
      if (span.end > end) end = span.end;
    }
    return ResolvedSpan(start, end);
  }

  ResolvedSpan _spanOf(AnimationNode node) {
    final span = _resolved[node.index];
    if (span == null) {
      throw StateError('$node is not resolved yet — resolve nodes in topological order.');
    }
    return span;
  }

  /// Auto placement delegates to [placeAuto].
  ResolvedSpan _placed(AnimationPhase phase, ResolvedSpan window, int duration, int delay) {
    final placed = placeAuto(
      phase: phase,
      windowStart: window.start,
      windowEnd: window.end,
      durationFrames: duration,
      delayFrames: delay,
    );
    return ResolvedSpan(placed.start, placed.end);
  }

  /// `end = sceneEnd − delay`, `start = end − duration`, whatever the phase.
  ResolvedSpan _endAnchored(int sceneEnd, int durationFrames, int delayFrames) {
    final end = sceneEnd - delayFrames;
    return ResolvedSpan(end - durationFrames, end);
  }

  TimeScopeData _sceneScope(AnimationNode node, TimeScopeData elementScope) {
    if (node.element.window == null) return elementScope;
    final scene = elementScope.parent;
    if (scene == null) {
      throw StateError(
        'The scope of a windowed element must be a child of its scene scope — '
        'build it with elementScopeFor.',
      );
    }
    return scene;
  }

  int _previousEnd(AnimationNode node) {
    if (node.animationIndex == 0) {
      throw firstAnimationPreviousError(node);
    }
    // An element's animations occupy consecutive global indices, so the
    // prior animation is exactly index - 1 (see AnimationNode.index).
    return _spanOf(_registry.nodes[node.index - 1]).end;
  }

  /// Snaps to the first qualifying beat at or after the window start; a
  /// missing grid or no beat strictly before the window end is an error.
  int _beatFrame(BeatTrigger trigger, AnimationNode node, ResolvedSpan window) {
    final track = trigger.track;
    final grid = track == null ? _plan.defaultBeatGrid : _plan.trackBeatGrids[track];
    if (grid == null) {
      throw FluvieTimingError(
        track == null
            ? "Trigger.beat on '${node.element.ownerId}' has no grid to "
                  'resolve against — attach a beat-tagged Audio track.'
            : "Trigger.beat on '${node.element.ownerId}' references a track "
                  'with no analysed beat grid.',
        anchors: [?track],
      );
    }
    final beat = grid.firstBeatAtOrAfter(window.start, every: trigger.every);
    if (beat == null || beat >= window.end) {
      throw FluvieTimingError(
        "Trigger.beat on '${node.element.ownerId}' found no qualifying beat "
        'between frames ${window.start} and ${window.end}.',
        anchors: [?track],
      );
    }
    return beat;
  }
}
