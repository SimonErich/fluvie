import 'package:fluvie/src/core/animation_phase.dart';

/// Places an auto-triggered animation within its element window — the pure
/// frame math, with every input already resolved.
///
/// * [AnimationPhase.enter] is start-anchored: it begins at
///   `windowStart + delayFrames` and runs for [durationFrames].
/// * [AnimationPhase.exit] is end-anchored: it **ends** at
///   `windowEnd - delayFrames`, so its start is computed for you.
/// * [AnimationPhase.during] spans `windowStart + delayFrames` to
///   [windowEnd] (looping joins per `repeat`).
///
/// This is raw placement: a span may overhang the window when the duration
/// exceeds it — out-of-bounds rows become *warnings* during composition
/// resolution, never silent clamps.
({int start, int end}) placeAuto({
  required AnimationPhase phase,
  required int windowStart,
  required int windowEnd,
  required int durationFrames,
  required int delayFrames,
}) => switch (phase) {
  AnimationPhase.enter => (
    start: windowStart + delayFrames,
    end: windowStart + delayFrames + durationFrames,
  ),
  AnimationPhase.exit => (
    start: windowEnd - delayFrames - durationFrames,
    end: windowEnd - delayFrames,
  ),
  AnimationPhase.during => (start: windowStart + delayFrames, end: windowEnd),
};
