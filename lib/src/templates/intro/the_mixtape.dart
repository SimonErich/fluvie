import 'dart:math' as math;

import 'package:flutter/material.dart' hide Easing;

import '../../presentation/time_consumer.dart';
import '../../presentation/video_composition.dart';
import '../../declarative/utils/easing.dart';
import '../../declarative/animations/core/animated_prop.dart';
import '../../declarative/animations/core/prop_animation.dart';
import '../_base/template_base.dart';
import '../_base/template_config.dart';
import '../_base/template_data.dart';

/// A stop-motion style animation of a cassette tape with dynamic label text.
///
/// Creates a nostalgic retro effect with a spinning cassette tape where
/// the label text is customizable. The tape reels spin to suggest playback.
///
/// Best used for:
/// - Music-related content
/// - Retro/nostalgic themes
/// - Playlist reveals
///
/// Example:
/// ```dart
/// TheMixtape(
///   data: IntroData(
///     title: 'Your Mixtape',
///     subtitle: 'Best of 2024',
///   ),
///   theme: TemplateTheme.retro,
/// )
/// ```
class TheMixtape extends WrappedTemplate with TemplateAnimationMixin {
  /// Speed of the cassette reel rotation.
  final double reelSpeed;

  /// Whether to show stop-motion effect (frame skipping).
  final bool stopMotion;

  /// Cassette label color.
  final Color? labelColor;

  const TheMixtape({
    super.key,
    required IntroData super.data,
    super.theme,
    super.timing,
    this.reelSpeed = 1.0,
    this.stopMotion = true,
    this.labelColor,
  });

  @override
  int get recommendedLength => 150;

  @override
  TemplateCategory get category => TemplateCategory.intro;

  @override
  String get description =>
      'Stop-motion cassette tape animation with dynamic label';

  @override
  TemplateTheme get defaultTheme => TemplateTheme.retro;

  IntroData get introData => data as IntroData;

  @override
  Widget build(BuildContext context) {
    final colors = effectiveTheme;
    final effectiveLabelColor = labelColor ?? colors.primaryColor;

    return Container(
      color: colors.backgroundColor,
      child: Stack(
        children: [
          // Background texture
          Positioned.fill(child: _buildRetroBackground(colors)),

          // Cassette tape
          Positioned.fill(
            child: Center(child: _buildCassette(colors, effectiveLabelColor)),
          ),

          // Text overlay
          Positioned.fill(child: _buildTextOverlay(colors)),
        ],
      ),
    );
  }

  Widget _buildRetroBackground(TemplateTheme colors) {
    return TimeConsumer(
      builder: (context, frame, _) {
        // Stop-motion grain effect
        final grainSeed = stopMotion ? (frame ~/ 2) : frame;
        final r = math.Random(grainSeed);

        return CustomPaint(
          painter: _RetroGrainPainter(
            grainDensity: 0.02,
            random: r,
            color: colors.textColor.withValues(alpha: 0.05),
          ),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildCassette(TemplateTheme colors, Color labelColor) {
    return TimeConsumer(
      builder: (context, frame, _) {
        final composition = VideoComposition.of(context);
        final fps = composition?.fps ?? 30;

        // Entry animation
        final entryProgress = calculateEntryProgress(frame, 10, 40);
        final entryScale = Curves.easeOutBack.transform(entryProgress);

        // Stop-motion effect - update only every few frames
        final effectiveFrame = stopMotion ? (frame ~/ 3) * 3 : frame;
        final time = effectiveFrame / fps;

        return Transform.scale(
          scale: entryScale,
          child: Opacity(
            opacity: entryProgress,
            child: Container(
              width: 500,
              height: 320,
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1A1A1A), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Label area
                  Positioned(
                    left: 20,
                    right: 20,
                    top: 20,
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: labelColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedProp(
                              startFrame: 50,
                              duration: 30,
                              animation: PropAnimation.fadeIn(),
                              child: Text(
                                introData.title.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: colors.backgroundColor,
                                  letterSpacing: 3,
                                ),
                              ),
                            ),
                            if (introData.subtitle != null) ...[
                              const SizedBox(height: 8),
                              AnimatedProp(
                                startFrame: 60,
                                duration: 25,
                                animation: PropAnimation.fadeIn(),
                                child: Text(
                                  introData.subtitle!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: colors.backgroundColor.withValues(
                                      alpha: 0.8,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Tape window
                  Positioned(
                    left: 50,
                    right: 50,
                    bottom: 50,
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF333333),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Left reel
                          _buildReel(time * reelSpeed, 70, colors),
                          // Tape strip
                          Container(
                            width: 100,
                            height: 20,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4A3728),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          // Right reel
                          _buildReel(-time * reelSpeed * 0.8, 70, colors),
                        ],
                      ),
                    ),
                  ),

                  // Screw holes
                  Positioned(left: 20, bottom: 20, child: _buildScrew()),
                  Positioned(right: 20, bottom: 20, child: _buildScrew()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReel(double rotation, double size, TemplateTheme colors) {
    return Transform.rotate(
      angle: rotation * 2 * math.pi,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF333333),
          border: Border.all(color: const Color(0xFF444444), width: 2),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Center hub
            Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF555555),
              ),
            ),
            // Spokes
            ...List.generate(6, (i) {
              return Transform.rotate(
                angle: i * math.pi / 3,
                child: Container(
                  width: 3,
                  height: size - 10,
                  color: const Color(0xFF444444),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildScrew() {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF555555),
        border: Border.all(color: const Color(0xFF666666)),
      ),
      child: Center(
        child: Container(width: 8, height: 2, color: const Color(0xFF444444)),
      ),
    );
  }

  Widget _buildTextOverlay(TemplateTheme colors) {
    return Column(
      children: [
        const Spacer(),
        if (introData.year != null)
          AnimatedProp(
            startFrame: 90,
            duration: 35,
            animation: PropAnimation.combine([
              PropAnimation.zoomIn(start: 0.7),
              PropAnimation.fadeIn(),
            ]),
            curve: Easing.easeOutBack,
            child: Text(
              '${introData.year}',
              style: TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.w900,
                color: colors.primaryColor,
                letterSpacing: 8,
              ),
            ),
          ),
        const SizedBox(height: 80),
      ],
    );
  }
}

/// Painter for retro grain effect.
class _RetroGrainPainter extends CustomPainter {
  final double grainDensity;
  final math.Random random;
  final Color color;

  _RetroGrainPainter({
    required this.grainDensity,
    required this.random,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;

    final count = (size.width * size.height * grainDensity).toInt();
    for (var i = 0; i < count; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final dotSize = random.nextDouble() * 2 + 1;
      canvas.drawCircle(Offset(x, y), dotSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RetroGrainPainter oldDelegate) => true;
}
