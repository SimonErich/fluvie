import 'dart:math' as math;

import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/transition.dart';
import 'package:fluvie/src/timing/placement/scene_frame_resolver.dart';
import 'package:fluvie/src/timing/relative_duration_guard.dart';

/// Every scene boundary of one composition, resolved to absolute frames: the
/// adjusted scene starts and durations, plus per-boundary transition frames
/// and overlap flags (boundary `i` sits between scenes `i` and `i + 1`).
typedef SceneOffsets = ({
  List<int> startFrames,
  List<int> durationFrames,
  List<int> transitionFrames,
  List<bool> overlaps,
  int totalFrames,
});

/// Resolves every scene start, duration, and transition window to frames at
/// [fps] — the single source of offset math.
///
/// Both `resolveCompositionDetailed` and the `Video` widget call this, so the
/// widget tree and the resolved plan can never disagree on adjusted scene
/// boundaries. Scene durations resolve through the shared boundary math;
/// [transitions] (one entry per boundary, `null` = cut) resolve to the blend
/// window lengths `F` and shift the offsets:
///
/// - **overlap:** `start[i+1] = start[i] + D[i] − F[i]` — the scenes share
///   the window and the total shortens by `F[i]`;
/// - **non-overlap:** starts and total stay unchanged — the blend overlays
///   the incoming scene's first `F[i]` frames while the outgoing is held at
///   its final frame.
///
/// An empty [transitions] list means all-cut and reproduces the plain
/// running sums byte-for-byte; any other length than `scenes − 1` throws an
/// [ArgumentError]. A relative transition duration throws a
/// [FluvieTimingError] naming both scenes (ambiguous between two windows),
/// and a transition rounding to zero frames degenerates to a cut, never an
/// error. Per scene, the incoming blend head plus the live outgoing tail
/// must fit: `F[i−1] + (overlap[i] ? F[i] : 0) ≤ D[i]`, else a
/// [FluvieTimingError] names the scene and both transitions.
///
/// [sceneIds] label scenes in error messages and default to the `scenes[i]`
/// convention the `Video` widget uses.
SceneOffsets resolveSceneOffsets({
  required int fps,
  required List<Time> durations,
  List<Transition?> transitions = const [],
  List<String>? sceneIds,
}) {
  final ids = sceneIds ?? [for (var s = 0; s < durations.length; s++) 'scenes[$s]'];
  assert(
    ids.length == durations.length,
    // coverage:ignore-line defensive assert message sceneIds always matches the scene count
    'sceneIds must label every scene: got ${ids.length} ids for ${durations.length} scenes.',
  );
  final boundaries = math.max(0, durations.length - 1);
  if (transitions.isNotEmpty && transitions.length != boundaries) {
    throw ArgumentError.value(
      transitions,
      'transitions',
      'must have one entry per scene boundary (= scenes - 1 = $boundaries) '
          'or be empty for all-cut; got ${transitions.length}',
    );
  }

  final durationFrames = [
    for (var s = 0; s < durations.length; s++)
      resolveSceneDurationFrames(durations[s], fps, ids[s]),
  ];
  final transitionFrames = <int>[];
  final overlaps = <bool>[];
  for (var b = 0; b < boundaries; b++) {
    final spec = transitions.isEmpty ? null : transitions[b];
    if (spec == null || spec.kind == TransitionKind.cut) {
      transitionFrames.add(0);
      overlaps.add(false);
      continue;
    }
    final frames = spec.duration.resolveFrames(
      RelativeDurationGuard(
        fps,
        'The duration of the transition between scenes ${_quote(ids[b])} and '
        '${_quote(ids[b + 1])} cannot be relative: a boundary sits between two scenes, so it '
        'is ambiguous which window the fraction would measure. Use frames, seconds, or ms '
        'for transition durations.',
      ),
    );
    transitionFrames.add(math.max(0, frames));
    overlaps.add(spec.overlap);
  }

  final startFrames = <int>[];
  var offset = 0;
  for (var s = 0; s < durations.length; s++) {
    startFrames.add(offset);
    final shift = s < boundaries && overlaps[s] ? transitionFrames[s] : 0;
    offset += durationFrames[s] - shift;
  }
  final totalFrames = durations.isEmpty ? 0 : startFrames.last + durationFrames.last;

  for (var s = 0; s < durations.length; s++) {
    _checkSceneFits(s, ids, durationFrames, transitionFrames, overlaps, transitions);
  }

  return (
    startFrames: List.unmodifiable(startFrames),
    durationFrames: List.unmodifiable(durationFrames),
    transitionFrames: List.unmodifiable(transitionFrames),
    overlaps: List.unmodifiable(overlaps),
    totalFrames: totalFrames,
  );
}

/// The D3 validation for scene [s]: the incoming blend head plus the live
/// outgoing tail must fit inside the scene, else a [FluvieTimingError] names
/// the scene and the transitions involved.
void _checkSceneFits(
  int s,
  List<String> ids,
  List<int> durationFrames,
  List<int> transitionFrames,
  List<bool> overlaps,
  List<Transition?> transitions,
) {
  final head = s > 0 ? transitionFrames[s - 1] : 0;
  final tail = s < transitionFrames.length && overlaps[s] ? transitionFrames[s] : 0;
  if (head + tail <= durationFrames[s]) return;
  final parts = <String>[
    if (head > 0) 'the incoming ${transitions[s - 1]?.kind.name} blend needs $head frames',
    if (tail > 0) 'the live outgoing ${transitions[s]?.kind.name} tail needs $tail frames',
  ];
  throw FluvieTimingError(
    'Scene ${_quote(ids[s])} (${durationFrames[s]} frames) cannot fit its transitions: '
    '${parts.join(' and ')} (${head + tail} > ${durationFrames[s]}). Lengthen the scene, '
    'shorten the transitions, or set overlap: false.',
  );
}

String _quote(String id) => "'$id'";
