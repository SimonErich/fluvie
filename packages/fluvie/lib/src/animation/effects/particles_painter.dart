import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show immutable;
import 'package:fluvie/src/core/noise/noise_source.dart';
import 'package:fluvie/src/core/particles/particles.dart';

/// One particle's resolved visual state at a frame — the pure output of
/// [particleAt], everything the painter needs to draw it.
@immutable
final class ParticleState {
  /// Bundles a particle's [center], [rotation] (radians), [size] (px),
  /// [color], and [alpha] (`0`–`1`).
  const ParticleState({
    required this.center,
    required this.rotation,
    required this.size,
    required this.color,
    required this.alpha,
  });

  /// Where the particle's center sits within the host bounds.
  final Offset center;

  /// The particle's rotation in radians (confetti tumbles; circles ignore it).
  final double rotation;

  /// The particle's edge length / diameter in logical pixels.
  final double size;

  /// The particle's color, chosen from the spec palette by its seed.
  final Color color;

  /// The particle's opacity in `[0, 1]` — sparkle twinkles through this.
  final double alpha;
}

/// Resolves particle [index] of [spec] at [progress] over a [size]-bounded
/// host, sampling [noise] — a pure function.
///
/// Every property derives from `noise.valueForSeed("${spec.seed}-$index-…")`,
/// so the same inputs always yield the same state, on every machine and pump.
/// [progress] scrolls the field: confetti and snow fall and wrap, while
/// sparkle barely moves and twinkles in alpha.
ParticleState particleAt({
  required Particles spec,
  required int index,
  required double progress,
  required Size size,
  required NoiseSource noise,
}) {
  final base = '${spec.seed}-$index';
  final lane = noise.valueForSeed('$base-x');
  final start = noise.valueForSeed('$base-y');
  final phase = noise.valueForSeed('$base-p');
  final scale = noise.valueForSeed('$base-s');
  final swing = noise.valueForSeed('$base-d');

  // Fall wraps within [0, 1) so the field recycles across the scene without a
  // seam; sparkle's tiny fallSpeed keeps it near its start.
  final fall = (start + progress * spec.fallSpeed) % 1.0;
  // Sideways wander: a sine of progress, seeded per particle so each lane
  // weaves differently but reproducibly.
  final wander = math.sin((progress + phase) * 2 * math.pi) * spec.drift;
  final x = ((lane + wander) % 1.0) * size.width;
  final y = fall * size.height;

  final particleSize = spec.minSize + scale * (spec.maxSize - spec.minSize);
  final rotation = (progress * spec.spinSpeed + swing) * 2 * math.pi;
  final color = spec.palette[index % spec.palette.length];
  final alpha = spec.kind == ParticleKind.sparkle
      ? 0.35 + 0.65 * (0.5 + 0.5 * math.sin((progress * spec.spinSpeed + phase) * 2 * math.pi))
      : 1.0;

  return ParticleState(
    center: Offset(x, y),
    rotation: rotation,
    size: particleSize,
    color: color,
    alpha: alpha,
  );
}

/// Paints the particle field for one (spec, progress) pair.
final class ParticlesPainter extends CustomPainter {
  /// Creates a painter drawing [spec] at [progress], sampling [noise].
  const ParticlesPainter({required this.spec, required this.progress, required this.noise});

  /// The field description.
  final Particles spec;

  /// The scene progress driving the fall and twinkle.
  final double progress;

  /// The seeded source behind every particle's placement.
  final NoiseSource noise;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var i = 0; i < spec.count; i++) {
      final p = particleAt(spec: spec, index: i, progress: progress, size: size, noise: noise);
      paint.color = p.color.withValues(alpha: p.alpha);
      if (spec.kind == ParticleKind.confetti) {
        _confetti(canvas, paint, p);
      } else {
        canvas.drawCircle(p.center, p.size / 2, paint);
      }
    }
  }

  /// Draws one tumbling confetti flake: a rotated square centered on its point.
  void _confetti(Canvas canvas, Paint paint, ParticleState p) {
    canvas
      ..save()
      ..translate(p.center.dx, p.center.dy)
      ..rotate(p.rotation)
      ..drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size), paint)
      ..restore();
  }

  @override
  bool shouldRepaint(ParticlesPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.spec != spec;
}
