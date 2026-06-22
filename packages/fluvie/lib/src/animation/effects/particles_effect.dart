import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/effect_kind.dart';
import 'package:fluvie/src/animation/effects/particles_painter.dart';
import 'package:fluvie/src/animation/runtime/noise_scope.dart';
import 'package:fluvie/src/core/noise/noise_source.dart';
import 'package:fluvie/src/core/noise/value_noise.dart';
import 'package:fluvie/src/core/particles/particles.dart';

/// The effect behind `Animation.particles`: a deterministic field of falling
/// or twinkling particles painted over the child.
///
/// A pixel post-effect — it wraps the child in a `CustomPaint(foregroundPainter:)`
/// so the field composites over the already-rendered element with no backdrop
/// read and no `saveLayer`, which keeps it `RepaintBoundary.toImage`-safe for
/// capture. Each particle's position, rotation, size, color, and alpha are a
/// pure function of its index, the effect's `progress`, and
/// `NoiseSource.valueForSeed("$seed-$i")`, so two pumps at the same frame paint
/// the same pixels (so it caches and goldens). `progress` advances
/// the field — confetti and snow fall, sparkle twinkles in place.
final class ParticlesEffect implements PixelAnimationEffect {
  /// Creates a particle field from [spec], sampling from [noise] (the const
  /// [ValueNoise] stub by default).
  const ParticlesEffect(this.spec, {NoiseSource noise = const ValueNoise()})
    : _noise = noise; // ignore: prefer_initializing_formals — public arg `noise`, private field

  /// The declarative description of the field.
  final Particles spec;

  final NoiseSource _noise;

  @override
  Widget build(Widget child, double progress) => Builder(
    builder: (context) => CustomPaint(
      // A mounted NoiseScope wins; otherwise the effect's own source (the const
      // ValueNoise() default), so a tree with no scope places byte-identically.
      foregroundPainter: ParticlesPainter(
        spec: spec,
        progress: progress,
        noise: NoiseScope.maybeOf(context) ?? _noise,
      ),
      child: child,
    ),
  );

  /// The center of every particle at [progress] over a [size]-bounded host —
  /// the same placements the painter draws, exposed for testing and reuse.
  ///
  /// Each offset is a pure function of the particle index, [progress], and the
  /// seeded noise lookup, so two calls always agree.
  List<Offset> placementsAt(double progress, Size size) => [
    for (var i = 0; i < spec.count; i++)
      particleAt(spec: spec, index: i, progress: progress, size: size, noise: _noise).center,
  ];

  @override
  String toString() => 'ParticlesEffect($spec)';
}
