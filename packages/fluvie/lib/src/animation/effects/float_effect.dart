import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/animation_effect.dart';
import 'package:fluvie/src/animation/runtime/noise_scope.dart';
import 'package:fluvie/src/core/noise/noise_source.dart';
import 'package:fluvie/src/core/noise/value_noise.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

/// The seeded variant behind `Animation.float(seed:)`: a gentle vertical bob
/// whose pure sine carries a low-amplitude, reproducible noise wobble.
///
/// A transform-class effect — it wraps the child in a [FractionalTranslation]
/// (no pixel post-process), so it composes with keyframe animations like any
/// other widget-level transform. Unlike the unseeded `float` (a pure-sine
/// keyframe preset), this reads the frame clock directly so the noise can be
/// sampled continuously between frames rather than at fixed keyframe stops.
///
/// The offset is [baseOffset] (the same `−amplitude·sin(2π·phase)` shape the
/// keyframe float traces) plus a noise term sampled *around a circle* in the
/// [NoiseSource] field. Sampling on a closed loop makes the noise exactly
/// periodic in the cycle phase, so the value at the last frame of one cycle and
/// the first of the next are continuous — the loop never jumps (the continuity
/// contract). [seed] shifts where on the noise field the circle
/// sits, so two seeds bob differently but each is fully reproducible.
final class FloatEffect implements AnimationEffect {
  /// Creates a seeded float of ± [amplitude] element-heights at [frequency]
  /// cycles per second, its wobble drawn from [noise] seeded by [seed].
  const FloatEffect({
    required this.seed,
    this.amplitude = 0.04,
    this.frequency = 0.4,
    NoiseSource noise = const ValueNoise(),
  }) : _noise = noise; // ignore: prefer_initializing_formals — public arg `noise`, private field

  /// The peak vertical travel as a fraction of the element's own height.
  final double amplitude;

  /// Cycles per second; the loop is `1/frequency` seconds long.
  final double frequency;

  /// The reproducibility seed: the same string always bobs the same way.
  final String seed;

  final NoiseSource _noise;

  /// How much of [amplitude] the noise wobble may add — kept low so the bob
  /// stays a recognisable float, only organically varied.
  static const double _noiseRatio = 0.4;

  /// The radius of the sampling circle in noise-lattice units; large enough to
  /// cross several lattice cells per cycle so the wobble actually varies.
  static const double _noiseRadius = 2.3;

  /// The pure sine the keyframe `float` traces: `0` at the cycle start, up
  /// (negative y) at a quarter, down (positive y) at three-quarters.
  static double baseOffset(int frame, int cycleFrames, double amplitude) {
    if (cycleFrames <= 0) return 0;
    final phase = (frame % cycleFrames) / cycleFrames;
    return -amplitude * math.sin(2 * math.pi * phase);
  }

  /// The full seeded offset at [frame]: [baseOffset] plus the periodic noise
  /// wobble, a pure function of its inputs (no clock, no unseeded `Random`).
  static double offsetAt({
    required int frame,
    required int cycleFrames,
    required double amplitude,
    required String seed,
    required NoiseSource noise,
  }) {
    final base = baseOffset(frame, cycleFrames, amplitude);
    if (cycleFrames <= 0) return base;
    final phase = (frame % cycleFrames) / cycleFrames;
    final angle = 2 * math.pi * phase;
    // Offset the sampling circle by a per-seed center so distinct seeds read
    // different parts of the field; sampling on the circle keeps it periodic.
    final cx = noise.valueForSeed('$seed-x') * 16;
    final cy = noise.valueForSeed('$seed-y') * 16;
    final sample = noise.noise2(
      cx + _noiseRadius * math.cos(angle),
      cy + _noiseRadius * math.sin(angle),
    );
    // Map the [0, 1] noise to [-1, 1] and scale it well below the sine.
    final wobble = (sample * 2 - 1) * amplitude * _noiseRatio;
    return base + wobble;
  }

  @override
  Widget build(Widget child, double progress) => _FloatView(
    amplitude: amplitude,
    frequency: frequency,
    seed: seed,
    noise: _noise,
    child: child,
  );

  @override
  String toString() => 'FloatEffect(amplitude: $amplitude, frequency: $frequency, seed: $seed)';
}

/// Reads the frame clock and scene fps to translate [child] by the seeded
/// float offset for the current frame.
final class _FloatView extends StatelessWidget {
  const _FloatView({
    required this.amplitude,
    required this.frequency,
    required this.seed,
    required this.noise,
    required this.child,
  });

  final double amplitude;
  final double frequency;
  final String seed;
  final NoiseSource noise;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final frame = FrameProvider.of(context).frame;
    final fps = TimeScopeProvider.of(context).fps;
    final cycleFrames = (fps / frequency).round();
    // A mounted NoiseScope wins; otherwise the effect's own source (the const
    // ValueNoise() default), so a tree with no scope bobs byte-identically.
    final dy = FloatEffect.offsetAt(
      frame: frame,
      cycleFrames: cycleFrames,
      amplitude: amplitude,
      seed: seed,
      noise: NoiseScope.maybeOf(context) ?? noise,
    );
    return FractionalTranslation(translation: Offset(0, dy), child: child);
  }
}
