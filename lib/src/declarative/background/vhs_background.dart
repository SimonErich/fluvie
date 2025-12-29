import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../presentation/time_consumer.dart';
import 'background.dart';

/// A VHS/retro video effect background overlay.
///
/// Creates a nostalgic VHS tape effect with chromatic aberration,
/// scanlines, tracking distortion, and optional noise. Perfect for
/// retro-themed videos.
///
/// Example:
/// ```dart
/// Scene(
///   background: Background.vhs(
///     baseColor: Colors.black,
///     intensity: 0.7,
///     showScanlines: true,
///   ),
///   children: [...],
/// )
/// ```
class VHSBackground extends Background {
  /// Base color of the background.
  final Color baseColor;

  /// Intensity of the VHS effect (0.0 - 1.0).
  final double intensity;

  /// Whether to show scanlines.
  final bool showScanlines;

  /// Whether to show chromatic aberration.
  final bool showChromatic;

  /// Whether to animate the effect.
  final bool animate;

  /// Whether to show tracking distortion.
  final bool showTracking;

  /// Random seed for reproducibility.
  final int seed;

  const VHSBackground({
    this.baseColor = const Color(0xFF000000),
    this.intensity = 0.5,
    this.showScanlines = true,
    this.showChromatic = true,
    this.animate = true,
    this.showTracking = true,
    this.seed = 42,
  });

  @override
  Widget build(BuildContext context, int sceneLength) {
    if (animate) {
      return TimeConsumer(
        builder: (context, frame, _) {
          return CustomPaint(
            painter: _VHSPainter(
              baseColor: baseColor,
              intensity: intensity,
              showScanlines: showScanlines,
              showChromatic: showChromatic,
              showTracking: showTracking,
              frame: frame,
              seed: seed,
            ),
            size: Size.infinite,
          );
        },
      );
    }

    return CustomPaint(
      painter: _VHSPainter(
        baseColor: baseColor,
        intensity: intensity,
        showScanlines: showScanlines,
        showChromatic: showChromatic,
        showTracking: showTracking,
        frame: 0,
        seed: seed,
      ),
      size: Size.infinite,
    );
  }
}

class _VHSPainter extends CustomPainter {
  final Color baseColor;
  final double intensity;
  final bool showScanlines;
  final bool showChromatic;
  final bool showTracking;
  final int frame;
  final int seed;

  _VHSPainter({
    required this.baseColor,
    required this.intensity,
    required this.showScanlines,
    required this.showChromatic,
    required this.showTracking,
    required this.frame,
    required this.seed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Base color
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = baseColor,
    );

    // Scanlines
    if (showScanlines) {
      _drawScanlines(canvas, size);
    }

    // Chromatic aberration effect
    if (showChromatic) {
      _drawChromaticAberration(canvas, size);
    }

    // Tracking distortion
    if (showTracking) {
      _drawTrackingDistortion(canvas, size);
    }

    // VHS noise
    _drawVHSNoise(canvas, size);

    // Moving scan line
    _drawMovingScanLine(canvas, size);
  }

  void _drawScanlines(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF000000).withValues(alpha: 0.1 * intensity);
    final lineHeight = 2.0;
    final gap = 2.0;

    for (var y = 0.0; y < size.height; y += lineHeight + gap) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, lineHeight), linePaint);
    }
  }

  void _drawChromaticAberration(Canvas canvas, Size size) {
    final random = math.Random(seed + frame ~/ 10);
    final offset = (2 + random.nextDouble() * 4) * intensity;

    // Red channel shift
    final redPaint = Paint()
      ..color = const Color(0xFFFF0000).withValues(alpha: 0.05 * intensity)
      ..blendMode = BlendMode.screen;

    canvas.drawRect(
      Rect.fromLTWH(-offset, 0, size.width, size.height),
      redPaint,
    );

    // Cyan channel shift
    final cyanPaint = Paint()
      ..color = const Color(0xFF00FFFF).withValues(alpha: 0.05 * intensity)
      ..blendMode = BlendMode.screen;

    canvas.drawRect(
      Rect.fromLTWH(offset, 0, size.width, size.height),
      cyanPaint,
    );
  }

  void _drawTrackingDistortion(Canvas canvas, Size size) {
    final random = math.Random(seed + frame);

    // Occasional tracking glitch
    if (random.nextDouble() > 0.95) {
      final glitchY = random.nextDouble() * size.height;
      final glitchHeight = 10 + random.nextDouble() * 30;
      final glitchOffset = (random.nextDouble() - 0.5) * 20 * intensity;

      // Draw distorted band
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, glitchY, size.width, glitchHeight));

      // Horizontal shift
      canvas.translate(glitchOffset, 0);

      // Draw noise in the band
      final noisePaint = Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.3 * intensity);

      for (var i = 0; i < 20; i++) {
        final x = random.nextDouble() * size.width;
        final w = random.nextDouble() * 50;
        canvas.drawRect(Rect.fromLTWH(x, glitchY, w, glitchHeight), noisePaint);
      }

      canvas.restore();
    }
  }

  void _drawVHSNoise(Canvas canvas, Size size) {
    final random = math.Random(seed + frame);
    final noiseCount = (50 * intensity).toInt();

    for (var i = 0; i < noiseCount; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final w = 1 + random.nextDouble() * 3;
      final h = 1 + random.nextDouble() * 2;

      final brightness = random.nextBool();
      final paint = Paint()
        ..color =
            (brightness ? const Color(0xFFFFFFFF) : const Color(0xFF000000))
                .withValues(alpha: random.nextDouble() * 0.1 * intensity);

      canvas.drawRect(Rect.fromLTWH(x, y, w, h), paint);
    }
  }

  void _drawMovingScanLine(Canvas canvas, Size size) {
    // Bright scan line that moves down the screen
    final scanY = (frame * 3.0) % (size.height + 50) - 25;

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFFFFFFFF).withValues(alpha: 0.0),
        const Color(0xFFFFFFFF).withValues(alpha: 0.03 * intensity),
        const Color(0xFFFFFFFF).withValues(alpha: 0.0),
      ],
    );

    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(0, scanY, size.width, 50));

    canvas.drawRect(Rect.fromLTWH(0, scanY, size.width, 50), paint);
  }

  @override
  bool shouldRepaint(covariant _VHSPainter oldDelegate) {
    return oldDelegate.frame != frame ||
        oldDelegate.intensity != intensity ||
        oldDelegate.baseColor != baseColor;
  }
}
