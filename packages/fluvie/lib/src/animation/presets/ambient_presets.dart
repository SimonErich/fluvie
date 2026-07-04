import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/effects/float_effect.dart';
import 'package:fluvie/src/animation/presets/preset_tail.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/edge.dart';
import 'package:fluvie/src/core/keyframe.dart';
import 'package:fluvie/src/core/repeat.dart';
import 'package:fluvie/src/core/time.dart';

/// Builds `Animation.float`: a vertical sine of ± [amplitude]
/// element-heights, looping forever at one [period] per cycle.
///
/// With no [seed] this is the pure-sine keyframe preset: five evenly-spaced
/// stops with gentle segment eases on a linear cycle (byte-identical to the
/// shipped behaviour). A non-null [seed] swaps in a [FloatEffect] that reads
/// the frame clock and adds a low-amplitude, reproducible noise wobble; that
/// branch needs an absolute [period] (seconds or milliseconds).
Animation buildFloat(double amplitude, Time period, AmbientTail tail, {String? seed}) {
  if (seed != null) return _buildSeededFloat(amplitude, _hzOf(period), seed, tail);
  return Animation.keyframes(
    [
      Keyframe.natural,
      Keyframe(y: -amplitude),
      Keyframe.natural,
      Keyframe(y: amplitude),
      Keyframe.natural,
    ],
    easings: const [Ease.gentle, Ease.gentle, Ease.gentle, Ease.gentle],
    phase: AnimationPhase.during,
    duration: period,
    ease: Ease.linear,
    delay: tail.delay,
    trigger: tail.at,
    stagger: tail.stagger,
    repeat: tail.repeat ?? const Repeat.forever(),
    label: tail.label,
  );
}

/// The cycle rate of an absolute [period], for the frame-clock [FloatEffect].
double _hzOf(Time period) => switch (period) {
  SecondTime(:final seconds) => 1 / seconds,
  MsTime(:final milliseconds) => 1000 / milliseconds,
  _ => throw ArgumentError.value(
    period,
    'period',
    'a seeded float needs an absolute period (seconds or milliseconds)',
  ),
};

/// The seeded `float` branch: a `during` [FloatEffect] looping forever, its
/// noise wobble keyed by [seed]. Kept separate so `buildFloat` stays a
/// simple router and the facade member stays a one-line delegation.
Animation _buildSeededFloat(double amplitude, double frequency, String seed, AmbientTail tail) =>
    Animation.custom(
      FloatEffect(seed: seed, amplitude: amplitude, frequency: frequency),
      phase: AnimationPhase.during,
      delay: tail.delay,
      at: tail.at,
      stagger: tail.stagger,
      repeat: tail.repeat ?? const Repeat.forever(),
      label: tail.label,
    );

/// Builds `Animation.pulse`: scale [min] → [max] over half a [period]
/// (the yoyo return completes the cycle), looping yoyo-forever.
Animation buildPulse(double min, double max, Time period, AmbientTail tail) => Animation.fromTo(
  Keyframe(scale: min),
  Keyframe(scale: max),
  phase: AnimationPhase.during,
  duration: period * 0.5,
  delay: tail.delay,
  at: tail.at,
  stagger: tail.stagger,
  repeat: tail.repeat ?? const Repeat.forever(yoyo: true),
  label: tail.label,
);

/// Builds `Animation.drift`: natural → [distance] element-sizes toward
/// the [to] edge, linear, one pass across the window (no repeat).
Animation buildDrift(Edge to, double distance, AmbientTail tail) => Animation.fromTo(
  Keyframe.natural,
  Keyframe(x: to.dx * distance, y: to.dy * distance),
  phase: AnimationPhase.during,
  ease: Ease.linear,
  delay: tail.delay,
  at: tail.at,
  stagger: tail.stagger,
  repeat: tail.repeat,
  label: tail.label,
);

/// Builds `Animation.spin`: rotation `0 → 1` turn over [per], linear,
/// looping forever.
Animation buildSpin(Time period, AmbientTail tail) => Animation.fromTo(
  const Keyframe(rotation: 0),
  const Keyframe(rotation: 1),
  phase: AnimationPhase.during,
  duration: period,
  ease: Ease.linear,
  delay: tail.delay,
  at: tail.at,
  stagger: tail.stagger,
  repeat: tail.repeat ?? const Repeat.forever(),
  label: tail.label,
);

/// Builds `Animation.kenBurns`: natural → `(scale: zoom,
/// x: −pan.dx·(zoom−1)/2, y: −pan.dy·(zoom−1)/2)`, linear, one pass — the
/// offset keeps the zoomed image covering its frame while panning.
Animation buildKenBurns(double zoom, Edge pan, AmbientTail tail) => Animation.fromTo(
  Keyframe.natural,
  Keyframe(scale: zoom, x: -pan.dx * (zoom - 1) / 2, y: -pan.dy * (zoom - 1) / 2),
  phase: AnimationPhase.during,
  ease: Ease.linear,
  delay: tail.delay,
  at: tail.at,
  stagger: tail.stagger,
  repeat: tail.repeat,
  label: tail.label,
);
