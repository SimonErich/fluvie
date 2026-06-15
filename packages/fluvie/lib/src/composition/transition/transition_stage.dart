import 'package:fluvie/src/core/transition.dart';
import 'package:fluvie/src/timing/placement/scene_offset_resolver.dart';
import 'package:meta/meta.dart';

/// What one scene is doing on one frame.
enum SceneRole {
  /// Outside its window: mounted offstage so registrations stay alive.
  hidden,

  /// Inside its window with no blend running: painted plain.
  solo,

  /// The earlier scene of an active blend window.
  outgoing,

  /// The later scene of an active blend window.
  incoming,
}

/// One scene's role on one frame, plus the blend payload when it is part of
/// an active window.
@immutable
final class SceneFrameState {
  /// Creates a state; blend fields stay at their defaults for [SceneRole.hidden]
  /// and [SceneRole.solo].
  const SceneFrameState({required this.role, this.progress = 0, this.holdFrame, this.boundary});

  /// What the scene is doing on this frame.
  final SceneRole role;

  /// The raw blend progress `p = (frame − blendStart + 1) / F` in `(0, 1]` —
  /// eased by the compositor, never here. `0` outside a
  /// blend.
  final double progress;

  /// The frame a non-overlap outgoing scene is held at, or
  /// `null` when the scene is live.
  final int? holdFrame;

  /// The boundary index of the active blend (`i` sits between scenes `i`
  /// and `i + 1`), or `null` outside one.
  final int? boundary;

  @override
  bool operator ==(Object other) =>
      other is SceneFrameState &&
      other.role == role &&
      other.progress == progress &&
      other.holdFrame == holdFrame &&
      other.boundary == boundary;

  @override
  int get hashCode => Object.hash(SceneFrameState, role, progress, holdFrame, boundary);

  @override
  String toString() =>
      'SceneFrameState(${role.name}'
      '${boundary == null ? '' : ', progress: $progress, boundary: $boundary'}'
      '${holdFrame == null ? '' : ', holdFrame: $holdFrame'})';
}

/// Resolves every scene's [SceneFrameState] at [frame] — the pure role math
/// behind the transition compositor.
///
/// The unifying invariant: a boundary's blend window is *always* the
/// incoming scene's first `F` frames, `[start[i+1], start[i+1] + F)`;
/// [Transition.overlap] only decides whether the outgoing is live (its
/// window still covers the blend) or held at its final frame. A `null` or
/// cut entry — and an `F` that rounded to zero — opens no window at all.
/// [transitions] must be empty (all-cut) or match [offsets]' boundary count.
List<SceneFrameState> stageAt({
  required int frame,
  required SceneOffsets offsets,
  required List<Transition?> transitions,
}) {
  assert(
    transitions.isEmpty || transitions.length == offsets.transitionFrames.length,
    // Reason: the assert message only builds on failure; the caller always
    // passes a matching count, so this string never executes in a valid run.
    // coverage:ignore-start
    'transitions (${transitions.length}) must be empty or match the '
    '${offsets.transitionFrames.length} boundaries of the offsets.',
    // coverage:ignore-end
  );
  return [
    for (var s = 0; s < offsets.startFrames.length; s++) _stateFor(s, frame, offsets, transitions),
  ];
}

SceneFrameState _stateFor(int s, int frame, SceneOffsets offsets, List<Transition?> transitions) {
  final starts = offsets.startFrames;

  bool blends(int b) {
    if (offsets.transitionFrames[b] <= 0) return false;
    final spec = transitions.isEmpty ? null : transitions[b];
    return spec != null && spec.kind != TransitionKind.cut;
  }

  /// p over boundary [b]'s window, or `null` when [frame] lies outside it.
  double? progressAt(int b) {
    final blendStart = starts[b + 1];
    final frames = offsets.transitionFrames[b];
    if (frame < blendStart || frame >= blendStart + frames) return null;
    return (frame - blendStart + 1) / frames;
  }

  if (s > 0 && blends(s - 1)) {
    final p = progressAt(s - 1);
    if (p != null) return SceneFrameState(role: SceneRole.incoming, progress: p, boundary: s - 1);
  }
  if (s < starts.length - 1 && blends(s)) {
    final p = progressAt(s);
    if (p != null) {
      return SceneFrameState(
        role: SceneRole.outgoing,
        progress: p,
        boundary: s,
        holdFrame: offsets.overlaps[s] ? null : starts[s + 1] - 1,
      );
    }
  }
  final inWindow = frame >= starts[s] && frame < starts[s] + offsets.durationFrames[s];
  return SceneFrameState(role: inWindow ? SceneRole.solo : SceneRole.hidden);
}
