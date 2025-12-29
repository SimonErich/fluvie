import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../presentation/time_consumer.dart';
import '../../declarative/animations/core/animated_prop.dart';
import '../../declarative/animations/core/prop_animation.dart';
import '../_base/template_base.dart';
import '../_base/template_config.dart';
import '../_base/template_data.dart';

/// A full-screen grunge texture with title "stamped" with ink-bleed effect.
///
/// Creates a raw, textured aesthetic where the title appears to be
/// stamped or printed onto a distressed background with organic
/// ink bleeding edges.
///
/// Best used for:
/// - Alternative/indie vibes
/// - Grunge aesthetics
/// - Underground/authentic feel
///
/// Example:
/// ```dart
/// NoiseID(
///   data: IntroData(
///     title: 'UNDERGROUND',
///     subtitle: '2024 Sounds',
///   ),
///   theme: TemplateTheme.minimal,
/// )
/// ```
class NoiseID extends WrappedTemplate with TemplateAnimationMixin {
  /// Intensity of the noise texture (0.0 - 1.0).
  final double noiseIntensity;

  /// Whether to animate the ink bleed effect.
  final bool animateInkBleed;

  /// Stamp color override.
  final Color? stampColor;

  const NoiseID({
    super.key,
    required IntroData super.data,
    super.theme,
    super.timing,
    this.noiseIntensity = 0.3,
    this.animateInkBleed = true,
    this.stampColor,
  });

  @override
  int get recommendedLength => 120;

  @override
  TemplateCategory get category => TemplateCategory.intro;

  @override
  String get description => 'Grunge texture with ink-bleed stamp effect title';

  @override
  TemplateTheme get defaultTheme => TemplateTheme.minimal;

  IntroData get introData => data as IntroData;

  @override
  Widget build(BuildContext context) {
    final colors = effectiveTheme;
    final effectiveStampColor = stampColor ?? colors.primaryColor;

    return Container(
      color: colors.backgroundColor,
      child: Stack(
        children: [
          // Grunge/noise texture
          Positioned.fill(child: _buildNoiseTexture(colors)),

          // Distressed overlay
          Positioned.fill(child: _buildDistressedOverlay(colors)),

          // Stamped title
          Positioned.fill(
            child: Center(
              child: _buildStampedContent(colors, effectiveStampColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoiseTexture(TemplateTheme colors) {
    return TimeConsumer(
      builder: (context, frame, _) {
        // Slight noise animation
        final seed = frame ~/ 4;
        return CustomPaint(
          painter: _NoiseTexturePainter(
            seed: seed,
            intensity: noiseIntensity,
            baseColor: colors.backgroundColor,
            noiseColor: colors.textColor,
          ),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildDistressedOverlay(TemplateTheme colors) {
    return TimeConsumer(
      builder: (context, frame, _) {
        final seed = 12345 + (frame ~/ 8);
        return CustomPaint(
          painter: _DistressedOverlayPainter(
            seed: seed,
            color: colors.textColor.withValues(alpha: 0.05),
          ),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildStampedContent(TemplateTheme colors, Color stampColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main title with stamp effect
        TimeConsumer(
          builder: (context, frame, _) {
            // Entry animation - stamp appears
            final entryProgress = calculateEntryProgress(frame, 20, 15);

            // Ink bleed animation
            double bleedAmount = 0;
            if (animateInkBleed && entryProgress >= 1.0) {
              final bleedProgress = calculateEntryProgress(frame, 35, 30);
              bleedAmount = bleedProgress * 3;
            }

            // Stamp "impact" scale effect
            double scale = 1.0;
            if (entryProgress > 0 && entryProgress < 1.0) {
              scale = 1.3 - (0.3 * entryProgress);
            }

            final opacity = entryProgress >= 0.5 ? 1.0 : 0.0;

            return Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: Stack(
                  children: [
                    // Ink bleed shadow layers
                    if (bleedAmount > 0) ...[
                      Transform.translate(
                        offset: Offset(-bleedAmount, -bleedAmount),
                        child: _buildStampText(
                          introData.title,
                          stampColor.withValues(alpha: 0.1),
                          colors,
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(bleedAmount, bleedAmount * 0.5),
                        child: _buildStampText(
                          introData.title,
                          stampColor.withValues(alpha: 0.1),
                          colors,
                        ),
                      ),
                    ],
                    // Main text
                    _buildStampText(introData.title, stampColor, colors),
                  ],
                ),
              ),
            );
          },
        ),

        // Subtitle
        if (introData.subtitle != null) ...[
          const SizedBox(height: 30),
          AnimatedProp(
            startFrame: 50,
            duration: 25,
            animation: PropAnimation.fadeIn(),
            child: Text(
              introData.subtitle!.toUpperCase(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: colors.textColor.withValues(alpha: 0.7),
                letterSpacing: 8,
              ),
            ),
          ),
        ],

        // Year
        if (introData.year != null) ...[
          const SizedBox(height: 40),
          AnimatedProp(
            startFrame: 70,
            duration: 30,
            animation: PropAnimation.combine([
              PropAnimation.slideUp(distance: 20),
              PropAnimation.fadeIn(),
            ]),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: stampColor, width: 3),
              ),
              child: Text(
                '${introData.year}',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: stampColor,
                  letterSpacing: 6,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStampText(String text, Color color, TemplateTheme colors) {
    return Text(
      text.toUpperCase(),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 100,
        fontWeight: FontWeight.w900,
        color: color,
        letterSpacing: 8,
        height: 0.9,
      ),
    );
  }
}

/// Painter for noise texture background.
class _NoiseTexturePainter extends CustomPainter {
  final int seed;
  final double intensity;
  final Color baseColor;
  final Color noiseColor;

  _NoiseTexturePainter({
    required this.seed,
    required this.intensity,
    required this.baseColor,
    required this.noiseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Fill background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = baseColor,
    );

    // Add noise
    final r = math.Random(seed);
    final paint = Paint();

    final step = 4.0;
    for (var x = 0.0; x < size.width; x += step) {
      for (var y = 0.0; y < size.height; y += step) {
        if (r.nextDouble() < intensity) {
          final brightness = r.nextDouble();
          paint.color = noiseColor.withValues(alpha: brightness * 0.15);
          canvas.drawRect(Rect.fromLTWH(x, y, step, step), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _NoiseTexturePainter oldDelegate) {
    return oldDelegate.seed != seed;
  }
}

/// Painter for distressed overlay effect.
class _DistressedOverlayPainter extends CustomPainter {
  final int seed;
  final Color color;

  _DistressedOverlayPainter({required this.seed, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random(seed);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw random scratches
    for (var i = 0; i < 20; i++) {
      final startX = r.nextDouble() * size.width;
      final startY = r.nextDouble() * size.height;
      final endX = startX + (r.nextDouble() - 0.5) * 200;
      final endY = startY + (r.nextDouble() - 0.5) * 200;

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
    }

    // Draw random spots
    for (var i = 0; i < 30; i++) {
      final x = r.nextDouble() * size.width;
      final y = r.nextDouble() * size.height;
      final radius = r.nextDouble() * 5 + 2;

      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = color.withValues(alpha: r.nextDouble() * 0.1),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DistressedOverlayPainter oldDelegate) {
    return oldDelegate.seed != seed;
  }
}
