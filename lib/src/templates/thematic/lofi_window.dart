import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../presentation/time_consumer.dart';
import '../../presentation/video_composition.dart';
import '../../declarative/animations/core/animated_prop.dart';
import '../../declarative/animations/core/prop_animation.dart';
import '../_base/template_base.dart';
import '../_base/template_config.dart';
import '../_base/template_data.dart';

/// Pixel-art rainy city with text as window condensation.
///
/// Creates a cozy, lo-fi aesthetic with a simulated rainy window view
/// overlooking a city. Text appears as if written on foggy glass,
/// with raindrops streaking down.
///
/// Best used for:
/// - Mood/vibe stats
/// - Lo-fi genre highlights
/// - Relaxation metrics
///
/// Example:
/// ```dart
/// LofiWindow(
///   data: ThematicData(
///     title: 'Late Night Vibes',
///     subtitle: '2,345 hours',
///     description: 'Your most listened genre after midnight',
///   ),
/// )
/// ```
class LofiWindow extends WrappedTemplate with TemplateAnimationMixin {
  /// Intensity of the rain.
  final double rainIntensity;

  /// Amount of window fog.
  final double fogAmount;

  /// Show city lights in background.
  final bool showCityLights;

  /// Random seed for rain pattern.
  final int seed;

  const LofiWindow({
    super.key,
    required ThematicData super.data,
    super.theme,
    super.timing,
    this.rainIntensity = 0.7,
    this.fogAmount = 0.4,
    this.showCityLights = true,
    this.seed = 42,
  });

  @override
  int get recommendedLength => 180;

  @override
  TemplateCategory get category => TemplateCategory.thematic;

  @override
  String get description => 'Pixel-art rainy city with condensation text';

  @override
  TemplateTheme get defaultTheme => TemplateTheme.midnight;

  ThematicData get thematicData => data as ThematicData;

  @override
  Widget build(BuildContext context) {
    final colors = effectiveTheme;

    return Container(
      color: colors.backgroundColor,
      child: Stack(
        children: [
          // City background
          Positioned.fill(child: _buildCityBackground(colors)),

          // Window fog layer
          Positioned.fill(child: _buildFogLayer(colors)),

          // Rain effect
          Positioned.fill(child: _buildRainEffect(colors)),

          // Condensation text
          Positioned.fill(child: Center(child: _buildCondensationText(colors))),
        ],
      ),
    );
  }

  Widget _buildCityBackground(TemplateTheme colors) {
    return TimeConsumer(
      builder: (context, frame, _) {
        final composition = VideoComposition.of(context);
        final fps = composition?.fps ?? 30;
        final time = frame / fps;

        return CustomPaint(
          painter: _CityBackgroundPainter(
            backgroundColor: colors.backgroundColor,
            buildingColor: colors.secondaryColor,
            lightColor: colors.accentColor,
            time: time,
            showLights: showCityLights,
            seed: seed,
          ),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildFogLayer(TemplateTheme colors) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [
            Colors.transparent,
            colors.backgroundColor.withValues(alpha: fogAmount * 0.3),
            colors.backgroundColor.withValues(alpha: fogAmount * 0.6),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  Widget _buildRainEffect(TemplateTheme colors) {
    return TimeConsumer(
      builder: (context, frame, _) {
        return CustomPaint(
          painter: _RainPainter(
            frame: frame,
            intensity: rainIntensity,
            color: colors.textColor.withValues(alpha: 0.3),
            seed: seed,
          ),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildCondensationText(TemplateTheme colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title - drawn on fogged glass
        AnimatedProp(
          startFrame: 40,
          duration: 50,
          animation: PropAnimation.combine([PropAnimation.fadeIn()]),
          child: Text(
            thematicData.title ?? 'Your Vibe',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w300,
              color: colors.textColor.withValues(alpha: 0.7),
              letterSpacing: 8,
              shadows: [
                Shadow(
                  color: colors.textColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Subtitle
        if (thematicData.subtitle != null)
          AnimatedProp(
            startFrame: 70,
            duration: 40,
            animation: PropAnimation.fadeIn(),
            child: Text(
              thematicData.subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w600,
                color: colors.accentColor.withValues(alpha: 0.9),
                shadows: [
                  Shadow(
                    color: colors.accentColor.withValues(alpha: 0.5),
                    blurRadius: 15,
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 30),

        // Description
        if (thematicData.description != null)
          AnimatedProp(
            startFrame: 100,
            duration: 30,
            animation: PropAnimation.slideUpFade(distance: 15),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: colors.backgroundColor.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                thematicData.description!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: colors.textColor.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CityBackgroundPainter extends CustomPainter {
  final Color backgroundColor;
  final Color buildingColor;
  final Color lightColor;
  final double time;
  final bool showLights;
  final int seed;

  _CityBackgroundPainter({
    required this.backgroundColor,
    required this.buildingColor,
    required this.lightColor,
    required this.time,
    required this.showLights,
    required this.seed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);

    // Sky gradient
    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          backgroundColor.withValues(alpha: 0.8),
          buildingColor.withValues(alpha: 0.5),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);

    // Draw buildings
    final buildingCount = 15;
    final buildingPaint = Paint()..color = buildingColor.withValues(alpha: 0.6);

    for (var i = 0; i < buildingCount; i++) {
      final x = (i / buildingCount) * size.width - 20;
      final width = 40 + random.nextDouble() * 60;
      final height = 100 + random.nextDouble() * (size.height * 0.5);
      final y = size.height - height;

      canvas.drawRect(Rect.fromLTWH(x, y, width, height), buildingPaint);

      // Windows
      if (showLights) {
        final windowPaint = Paint()..color = lightColor;
        final windowSize = 6.0;
        final windowGap = 12.0;

        for (var wx = x + 8; wx < x + width - 8; wx += windowGap) {
          for (var wy = y + 10; wy < size.height - 10; wy += windowGap) {
            // Random window light state with flickering
            final lightOn = random.nextDouble() > 0.4;
            final flicker = math.sin(time * 3 + wx + wy) > 0.8;

            if (lightOn && !flicker) {
              final intensity = 0.5 + random.nextDouble() * 0.5;
              windowPaint.color = lightColor.withValues(alpha: intensity);
              canvas.drawRect(
                Rect.fromLTWH(wx, wy, windowSize, windowSize),
                windowPaint,
              );
            }
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CityBackgroundPainter oldDelegate) {
    return oldDelegate.time != time;
  }
}

class _RainPainter extends CustomPainter {
  final int frame;
  final double intensity;
  final Color color;
  final int seed;

  _RainPainter({
    required this.frame,
    required this.intensity,
    required this.color,
    required this.seed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    final dropCount = (100 * intensity).toInt();
    final dropPaint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < dropCount; i++) {
      final x = random.nextDouble() * size.width;
      final speed = 8 + random.nextDouble() * 4;
      final length = 20 + random.nextDouble() * 30;

      // Calculate drop position with animation
      final baseY = random.nextDouble() * size.height;
      final y = (baseY + frame * speed) % (size.height + length) - length;

      // Slight angle for wind effect
      final angle = 0.1;
      final endX = x + length * math.sin(angle);
      final endY = y + length * math.cos(angle);

      canvas.drawLine(Offset(x, y), Offset(endX, endY), dropPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RainPainter oldDelegate) {
    return oldDelegate.frame != frame;
  }
}
