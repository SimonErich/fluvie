import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../presentation/time_consumer.dart';
import 'background.dart';

/// A noise/grain overlay background effect.
///
/// Creates a film grain or static noise effect that overlays the content,
/// adding texture and visual interest.
///
/// Example:
/// ```dart
/// Scene(
///   background: Background.noise(
///     intensity: 0.05,
///     animate: true,
///   ),
///   children: [...],
/// )
/// ```
class NoiseBackground extends Background {
  /// Intensity of the noise effect (0.0 - 1.0).
  final double intensity;

  /// Color of the noise particles.
  final Color color;

  /// Random seed for reproducibility.
  final int seed;

  /// Whether to animate the noise.
  final bool animate;

  /// Animation speed (frames between updates).
  final int animationSpeed;

  const NoiseBackground({
    this.intensity = 0.05,
    this.color = const Color(0xFFFFFFFF),
    this.seed = 42,
    this.animate = true,
    this.animationSpeed = 2,
  });

  @override
  Widget build(BuildContext context, int sceneLength) {
    if (animate) {
      return TimeConsumer(
        builder: (context, frame, _) {
          final effectiveSeed = seed + (frame ~/ animationSpeed);
          return CustomPaint(
            painter: _NoisePainter(
              intensity: intensity,
              color: color,
              seed: effectiveSeed,
            ),
            size: Size.infinite,
          );
        },
      );
    }

    return CustomPaint(
      painter: _NoisePainter(intensity: intensity, color: color, seed: seed),
      size: Size.infinite,
    );
  }
}

class _NoisePainter extends CustomPainter {
  final double intensity;
  final Color color;
  final int seed;

  _NoisePainter({
    required this.intensity,
    required this.color,
    required this.seed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    final paint = Paint();

    // Calculate grain density based on intensity
    const step = 3.0;
    final maxOpacity = intensity.clamp(0.0, 0.3);

    for (var x = 0.0; x < size.width; x += step) {
      for (var y = 0.0; y < size.height; y += step) {
        if (random.nextDouble() < intensity) {
          final opacity = random.nextDouble() * maxOpacity;
          paint.color = color.withValues(alpha: opacity);
          canvas.drawRect(Rect.fromLTWH(x, y, step, step), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _NoisePainter oldDelegate) {
    return oldDelegate.seed != seed ||
        oldDelegate.intensity != intensity ||
        oldDelegate.color != color;
  }
}
