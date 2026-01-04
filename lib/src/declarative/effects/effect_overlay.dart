import 'dart:math' as math;
import 'package:flutter/widgets.dart';

import '../../presentation/time_consumer.dart';
import '../../presentation/video_composition.dart';

/// Type of effect overlay.
enum EffectType {
  /// Horizontal scanlines effect.
  scanlines,

  /// Film grain noise effect.
  grain,

  /// Vignette (darkened edges) effect.
  vignette,

  /// Grid overlay effect.
  grid,

  /// CRT monitor effect (scanlines + curvature).
  crt,

  /// Chromatic aberration effect.
  chromaticAberration,
}

/// A widget that applies visual effect overlays.
///
/// [EffectOverlay] renders various post-processing effects like scanlines,
/// grain, vignette, etc. These are rendered as overlays and can be combined.
///
/// Example:
/// ```dart
/// Stack(
///   children: [
///     MyContent(),
///     EffectOverlay.scanlines(intensity: 0.02),
///     EffectOverlay.vignette(intensity: 0.4),
///   ],
/// )
/// ```
class EffectOverlay extends StatelessWidget {
  /// The type of effect.
  final EffectType type;

  /// Intensity of the effect (0.0 to 1.0).
  final double intensity;

  /// Color for effects that use color (e.g., grid).
  final Color? color;

  /// Random seed for grain effect.
  final int? randomSeed;

  /// Creates an effect overlay.
  const EffectOverlay({
    super.key,
    required this.type,
    this.intensity = 0.5,
    this.color,
    this.randomSeed,
  });

  /// Creates a scanlines effect.
  const EffectOverlay.scanlines({super.key, this.intensity = 0.02})
      : type = EffectType.scanlines,
        color = null,
        randomSeed = null;

  /// Creates a film grain effect.
  const EffectOverlay.grain({super.key, this.intensity = 0.06, this.randomSeed})
      : type = EffectType.grain,
        color = null;

  /// Creates a vignette effect.
  const EffectOverlay.vignette({super.key, this.intensity = 0.4})
      : type = EffectType.vignette,
        color = null,
        randomSeed = null;

  /// Creates a grid overlay effect.
  const EffectOverlay.grid({
    super.key,
    this.intensity = 0.05,
    this.color = const Color(0xFFFFFFFF),
  })  : type = EffectType.grid,
        randomSeed = null;

  /// Creates a CRT monitor effect.
  const EffectOverlay.crt({super.key, this.intensity = 0.3})
      : type = EffectType.crt,
        color = null,
        randomSeed = null;

  @override
  Widget build(BuildContext context) {
    // Grain needs to animate, others are static
    if (type == EffectType.grain) {
      return TimeConsumer(
        builder: (context, frame, _) {
          final composition = VideoComposition.of(context);
          final mq = MediaQuery.of(context);
          final width = composition?.width.toDouble() ?? mq.size.width;
          final height = composition?.height.toDouble() ?? mq.size.height;

          return CustomPaint(
            size: Size(width, height),
            painter: _GrainPainter(
              intensity: intensity,
              seed: (randomSeed ?? 42) + frame, // Different grain each frame
            ),
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final composition = VideoComposition.of(context);
        final width = composition?.width.toDouble() ?? constraints.maxWidth;
        final height = composition?.height.toDouble() ?? constraints.maxHeight;

        return CustomPaint(
          size: Size(width, height),
          painter: _getEffectPainter(width, height),
        );
      },
    );
  }

  CustomPainter _getEffectPainter(double width, double height) {
    switch (type) {
      case EffectType.scanlines:
        return _ScanlinesPainter(intensity: intensity);
      case EffectType.grain:
        return _GrainPainter(intensity: intensity, seed: randomSeed ?? 42);
      case EffectType.vignette:
        return _VignettePainter(intensity: intensity);
      case EffectType.grid:
        return _GridPainter(
          intensity: intensity,
          color: color ?? const Color(0xFFFFFFFF),
        );
      case EffectType.crt:
        return _CrtPainter(intensity: intensity);
      case EffectType.chromaticAberration:
        return _ChromaticAberrationPainter(intensity: intensity);
    }
  }
}

class _ScanlinesPainter extends CustomPainter {
  final double intensity;

  _ScanlinesPainter({required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color.fromRGBO(0, 0, 0, intensity)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw horizontal lines every 2 pixels
    for (double y = 0; y < size.height; y += 2) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanlinesPainter oldDelegate) {
    return oldDelegate.intensity != intensity;
  }
}

class _GrainPainter extends CustomPainter {
  final double intensity;
  final int seed;

  _GrainPainter({required this.intensity, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    final grainSize = 4.0; // Size of grain blocks

    for (double x = 0; x < size.width; x += grainSize) {
      for (double y = 0; y < size.height; y += grainSize) {
        if (random.nextDouble() < 0.3) {
          // Only draw grain on some pixels
          final brightness = random.nextDouble();
          final paint = Paint()
            ..color = Color.fromRGBO(
              (brightness * 255).toInt(),
              (brightness * 255).toInt(),
              (brightness * 255).toInt(),
              intensity,
            )
            ..style = PaintingStyle.fill;

          canvas.drawRect(Rect.fromLTWH(x, y, grainSize, grainSize), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GrainPainter oldDelegate) {
    return oldDelegate.seed != seed || oldDelegate.intensity != intensity;
  }
}

class _VignettePainter extends CustomPainter {
  final double intensity;

  _VignettePainter({required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius =
        math.sqrt(size.width * size.width + size.height * size.height) / 2;

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0x00000000), Color.fromRGBO(0, 0, 0, intensity)],
        stops: const [0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _VignettePainter oldDelegate) {
    return oldDelegate.intensity != intensity;
  }
}

class _GridPainter extends CustomPainter {
  final double intensity;
  final Color color;

  _GridPainter({required this.intensity, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: intensity)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const spacing = 50.0;

    // Vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.intensity != intensity || oldDelegate.color != color;
  }
}

class _CrtPainter extends CustomPainter {
  final double intensity;

  _CrtPainter({required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw scanlines
    final scanlinePaint = Paint()
      ..color = Color.fromRGBO(0, 0, 0, intensity * 0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanlinePaint);
    }

    // Draw subtle vignette
    final center = Offset(size.width / 2, size.height / 2);
    final radius =
        math.sqrt(size.width * size.width + size.height * size.height) / 2;

    final vignettePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0x00000000),
          Color.fromRGBO(0, 0, 0, intensity * 0.5),
        ],
        stops: const [0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawRect(Offset.zero & size, vignettePaint);
  }

  @override
  bool shouldRepaint(covariant _CrtPainter oldDelegate) {
    return oldDelegate.intensity != intensity;
  }
}

class _ChromaticAberrationPainter extends CustomPainter {
  final double intensity;

  _ChromaticAberrationPainter({required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    // This is a simplified representation - full chromatic aberration
    // would require manipulating the actual image pixels.
    // Here we just add colored edge glow.
    final offset = intensity * 10;

    // Red edge (left)
    final redPaint = Paint()
      ..color = Color.fromRGBO(255, 0, 0, intensity * 0.3)
      ..strokeWidth = offset
      ..style = PaintingStyle.stroke;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), redPaint);

    // Cyan edge (right)
    final cyanPaint = Paint()
      ..color = Color.fromRGBO(0, 255, 255, intensity * 0.3)
      ..strokeWidth = offset
      ..style = PaintingStyle.stroke;
    canvas.drawRect(
      Rect.fromLTWH(
        offset,
        offset,
        size.width - offset * 2,
        size.height - offset * 2,
      ),
      cyanPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ChromaticAberrationPainter oldDelegate) {
    return oldDelegate.intensity != intensity;
  }
}
