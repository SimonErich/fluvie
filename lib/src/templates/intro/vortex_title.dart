import 'dart:math' as math;

import 'package:flutter/material.dart' hide Easing;

import '../../presentation/time_consumer.dart';
import '../../presentation/video_composition.dart';
import '../../declarative/utils/easing.dart';
import '../../declarative/animations/core/animated_prop.dart';
import '../../declarative/animations/core/prop_animation.dart';
import '../../declarative/effects/particle_effect.dart';
import '../_base/template_base.dart';
import '../_base/template_config.dart';
import '../_base/template_data.dart';

/// Large typography that spirals in from the corners, converging into the center.
///
/// Creates a dynamic vortex effect where text characters or words spin
/// inward from different corners, creating a hypnotic convergence effect.
///
/// Best used for:
/// - Dramatic title reveals
/// - Word emphasis
/// - Energy-filled intros
///
/// Example:
/// ```dart
/// VortexTitle(
///   data: IntroData(
///     title: 'WRAPPED',
///     year: 2024,
///   ),
///   theme: TemplateTheme.neon,
/// )
/// ```
class VortexTitle extends WrappedTemplate with TemplateAnimationMixin {
  /// Whether to animate individual letters or the whole title.
  final bool animateLetters;

  /// Speed of the spiral rotation.
  final double spiralSpeed;

  /// Number of spiral rotations before settling.
  final double spiralRotations;

  /// Whether to show trailing particle effects.
  final bool showTrails;

  const VortexTitle({
    super.key,
    required IntroData super.data,
    super.theme,
    super.timing,
    this.animateLetters = true,
    this.spiralSpeed = 1.0,
    this.spiralRotations = 2.0,
    this.showTrails = true,
  });

  @override
  int get recommendedLength => 180;

  @override
  TemplateCategory get category => TemplateCategory.intro;

  @override
  String get description =>
      'Typography spirals in from corners, converging at center';

  @override
  TemplateTheme get defaultTheme => TemplateTheme.neon;

  IntroData get introData => data as IntroData;

  @override
  Widget build(BuildContext context) {
    final colors = effectiveTheme;

    return Container(
      color: colors.backgroundColor,
      child: Stack(
        children: [
          // Background particles
          if (showTrails)
            Positioned.fill(
              child: ParticleEffect.sparkles(
                count: 40,
                color: colors.primaryColor.withValues(alpha: 0.4),
              ),
            ),

          // Vortex lines (decorative)
          Positioned.fill(child: _buildVortexLines(colors)),

          // Main spiraling text
          Positioned.fill(child: Center(child: _buildSpiralingContent(colors))),

          // Subtitle appears after convergence
          Positioned.fill(child: _buildSubtitle(colors)),
        ],
      ),
    );
  }

  Widget _buildVortexLines(TemplateTheme colors) {
    return TimeConsumer(
      builder: (context, frame, _) {
        final composition = VideoComposition.of(context);
        final fps = composition?.fps ?? 30;
        final time = frame / fps;

        return CustomPaint(
          painter: _VortexLinesPainter(
            time: time,
            primaryColor: colors.primaryColor,
            secondaryColor: colors.secondaryColor,
            progress: (frame / 90).clamp(0.0, 1.0),
          ),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildSpiralingContent(TemplateTheme colors) {
    if (animateLetters) {
      return _buildSpiralingLetters(colors);
    } else {
      return _buildSpiralingTitle(colors);
    }
  }

  Widget _buildSpiralingLetters(TemplateTheme colors) {
    final letters = introData.title.split('');

    return TimeConsumer(
      builder: (context, frame, _) {
        final size = MediaQuery.of(context).size;

        return Stack(
          alignment: Alignment.center,
          children: List.generate(letters.length, (index) {
            final letter = letters[index];
            if (letter == ' ') return const SizedBox.shrink();

            // Each letter starts from a different corner with different timing
            final startDelay = index * 3;
            final animDuration = 60 * spiralSpeed;
            final progress = ((frame - startDelay) / animDuration).clamp(
              0.0,
              1.0,
            );
            final easedProgress = Curves.easeOutCubic.transform(progress);

            // Starting position (corners and edges)
            final startAngle = (index / letters.length) * 2 * math.pi;
            final startRadius = math.max(size.width, size.height) * 0.8;

            // Current position - spiral inward
            final currentRadius = startRadius * (1 - easedProgress);
            final spiralAngle =
                startAngle + (spiralRotations * 2 * math.pi * easedProgress);
            final currentX = math.cos(spiralAngle) * currentRadius;
            final currentY = math.sin(spiralAngle) * currentRadius;

            // Final position (centered, stacked horizontally)
            const letterWidth = 80.0;
            final totalWidth = letters.length * letterWidth * 0.6;
            final finalX = -totalWidth / 2 + index * letterWidth * 0.6;

            // Interpolate between spiral and final position
            final settleProgress =
                ((frame - (startDelay + animDuration * 0.7)) /
                        (animDuration * 0.3))
                    .clamp(0.0, 1.0);
            final settleEased = Curves.easeOutBack.transform(settleProgress);

            final x = currentX + (finalX - currentX) * settleEased;
            final y = currentY * (1 - settleEased);

            // Rotation
            final rotation = spiralAngle * (1 - settleEased);

            // Scale
            final scale = 0.3 + 0.7 * easedProgress;

            // Opacity
            final opacity = easedProgress.clamp(0.0, 1.0);

            return Transform.translate(
              offset: Offset(x, y),
              child: Transform.rotate(
                angle: rotation,
                child: Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity,
                    child: Text(
                      letter,
                      style: TextStyle(
                        fontSize: 100,
                        fontWeight: FontWeight.w900,
                        color: colors.textColor,
                        shadows: [
                          Shadow(
                            color: colors.primaryColor.withValues(alpha: 0.8),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildSpiralingTitle(TemplateTheme colors) {
    return TimeConsumer(
      builder: (context, frame, _) {
        final size = MediaQuery.of(context).size;

        final animDuration = 60 * spiralSpeed;
        final progress = (frame / animDuration).clamp(0.0, 1.0);
        final easedProgress = Curves.easeOutCubic.transform(progress);

        // Spiral from top-right corner
        final startRadius = math.max(size.width, size.height);
        final currentRadius = startRadius * (1 - easedProgress);
        final spiralAngle = spiralRotations * 2 * math.pi * easedProgress;
        final x = math.cos(spiralAngle - math.pi / 4) * currentRadius;
        final y = math.sin(spiralAngle - math.pi / 4) * currentRadius;

        final rotation = spiralAngle * (1 - easedProgress);
        final scale = 0.3 + 0.7 * easedProgress;
        final opacity = easedProgress.clamp(0.0, 1.0);

        return Transform.translate(
          offset: Offset(x, y),
          child: Transform.rotate(
            angle: rotation,
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: Text(
                  introData.title,
                  style: TextStyle(
                    fontSize: 80,
                    fontWeight: FontWeight.w900,
                    color: colors.textColor,
                    letterSpacing: 10,
                    shadows: [
                      Shadow(color: colors.primaryColor, blurRadius: 30),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubtitle(TemplateTheme colors) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 150),
        if (introData.year != null)
          AnimatedProp(
            startFrame: 100,
            duration: 40,
            animation: PropAnimation.combine([
              PropAnimation.zoomIn(start: 0.5),
              PropAnimation.fadeIn(),
            ]),
            curve: Easing.elastic,
            child: Text(
              '${introData.year}',
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w900,
                color: colors.primaryColor,
                letterSpacing: 10,
              ),
            ),
          ),
        if (introData.subtitle != null) ...[
          const SizedBox(height: 20),
          AnimatedProp(
            startFrame: 120,
            duration: 30,
            animation: PropAnimation.slideUpFade(distance: 30),
            child: Text(
              introData.subtitle!,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w400,
                color: colors.textColor.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Painter for decorative vortex lines.
class _VortexLinesPainter extends CustomPainter {
  final double time;
  final Color primaryColor;
  final Color secondaryColor;
  final double progress;

  _VortexLinesPainter({
    required this.time,
    required this.primaryColor,
    required this.secondaryColor,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.max(size.width, size.height) * 0.7;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw multiple spiral arms
    for (var arm = 0; arm < 4; arm++) {
      final armOffset = arm * math.pi / 2;

      final path = Path();
      var firstPoint = true;

      for (var t = 0.0; t <= 1.0; t += 0.02) {
        final angle = t * 4 * math.pi + time * 2 + armOffset;
        final radius = maxRadius * t * progress;
        final x = center.dx + math.cos(angle) * radius;
        final y = center.dy + math.sin(angle) * radius;

        if (firstPoint) {
          path.moveTo(x, y);
          firstPoint = false;
        } else {
          path.lineTo(x, y);
        }
      }

      paint.color = Color.lerp(
        primaryColor.withValues(alpha: 0.3),
        secondaryColor.withValues(alpha: 0.3),
        arm / 4,
      )!;

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _VortexLinesPainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.progress != progress;
  }
}
