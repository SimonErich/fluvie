import 'dart:math' as math;

import 'package:flutter/material.dart' hide Easing;

import '../../presentation/time_consumer.dart';
import '../../declarative/utils/easing.dart';
import '../../declarative/animations/core/animated_prop.dart';
import '../../declarative/animations/core/prop_animation.dart';
import '../_base/template_base.dart';
import '../_base/template_config.dart';
import '../_base/template_data.dart';

/// All elements on screen explode into tiny particles flying toward the camera.
///
/// Creates a dramatic finale where the farewell message and elements
/// burst into particles that rush toward the viewer, creating an
/// immersive, explosive ending.
///
/// Best used for:
/// - Dramatic endings
/// - Video conclusions
/// - "See you next year" moments
///
/// Example:
/// ```dart
/// ParticleFarewell(
///   data: SummaryData(
///     message: 'Until next time',
///     year: 2025,
///   ),
/// )
/// ```
class ParticleFarewell extends WrappedTemplate with TemplateAnimationMixin {
  /// Number of particles in the explosion.
  final int particleCount;

  /// Duration of the explosion effect in frames.
  final int explosionDuration;

  const ParticleFarewell({
    super.key,
    required SummaryData super.data,
    super.theme,
    super.timing,
    this.particleCount = 200,
    this.explosionDuration = 60,
  });

  @override
  int get recommendedLength => 150;

  @override
  TemplateCategory get category => TemplateCategory.conclusion;

  @override
  String get description =>
      'Elements explode into particles flying toward camera';

  @override
  TemplateTheme get defaultTheme => TemplateTheme.midnight;

  SummaryData get summaryData => data as SummaryData;

  @override
  Widget build(BuildContext context) {
    final colors = effectiveTheme;

    return Container(
      color: colors.backgroundColor,
      child: TimeConsumer(
        builder: (context, frame, _) {
          final explosionStart = 80;
          final explosionProgress =
              ((frame - explosionStart) / explosionDuration).clamp(0.0, 1.0);
          final beforeExplosion = frame < explosionStart;

          return Stack(
            children: [
              // Content (fades and explodes)
              if (beforeExplosion || explosionProgress < 0.3)
                Positioned.fill(
                  child: _buildContent(colors, frame, explosionProgress),
                ),

              // Particle explosion
              if (explosionProgress > 0)
                Positioned.fill(
                  child: _buildParticleExplosion(
                    colors,
                    explosionProgress,
                    frame,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(
    TemplateTheme colors,
    int frame,
    double explosionProgress,
  ) {
    // Fade and scale down as explosion starts
    final contentOpacity = (1.0 - explosionProgress * 2).clamp(0.0, 1.0);
    final contentScale = 1.0 - explosionProgress * 0.5;

    return Transform.scale(
      scale: contentScale,
      child: Opacity(
        opacity: contentOpacity,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main message
              AnimatedProp(
                startFrame: 15,
                duration: 35,
                animation: PropAnimation.combine([
                  PropAnimation.zoomIn(start: 0.5),
                  PropAnimation.fadeIn(),
                ]),
                curve: Easing.easeOutBack,
                child: Text(
                  summaryData.message ?? 'Until Next Time',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    color: colors.textColor,
                    letterSpacing: 3,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Year
              if (summaryData.year != null)
                AnimatedProp(
                  startFrame: 40,
                  duration: 30,
                  animation: PropAnimation.combine([
                    PropAnimation.zoomIn(start: 0.3),
                    PropAnimation.fadeIn(),
                  ]),
                  curve: Easing.elastic,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primaryColor,
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: colors.primaryColor.withValues(alpha: 0.5),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Text(
                      summaryData.year.toString(),
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: colors.backgroundColor,
                        letterSpacing: 6,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParticleExplosion(
    TemplateTheme colors,
    double progress,
    int frame,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final centerX = constraints.maxWidth / 2;
        final centerY = constraints.maxHeight / 2;
        final maxDistance = math.max(centerX, centerY) * 2;

        // Generate deterministic particles
        final particles = List.generate(particleCount, (index) {
          final random = math.Random(index * 12345);
          return _Particle(
            angle: random.nextDouble() * 2 * math.pi,
            speed: 0.5 + random.nextDouble() * 1.5,
            size: 2 + random.nextDouble() * 8,
            color: Color.lerp(
              colors.primaryColor,
              colors.secondaryColor,
              random.nextDouble(),
            )!,
            startDelay: random.nextDouble() * 0.2,
            z: random.nextDouble(), // Depth for perspective
          );
        });

        return CustomPaint(
          painter: _ParticleExplosionPainter(
            particles: particles,
            progress: progress,
            centerX: centerX,
            centerY: centerY,
            maxDistance: maxDistance,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Particle {
  final double angle;
  final double speed;
  final double size;
  final Color color;
  final double startDelay;
  final double z;

  _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.startDelay,
    required this.z,
  });
}

class _ParticleExplosionPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final double centerX;
  final double centerY;
  final double maxDistance;

  _ParticleExplosionPainter({
    required this.particles,
    required this.progress,
    required this.centerX,
    required this.centerY,
    required this.maxDistance,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      // Apply start delay
      final adjustedProgress =
          ((progress - particle.startDelay) / (1 - particle.startDelay)).clamp(
        0.0,
        1.0,
      );

      if (adjustedProgress <= 0) continue;

      // Ease the progress for natural motion
      final easedProgress = Curves.easeOutQuad.transform(adjustedProgress);

      // Calculate position
      // Particles move toward camera (scale up and move outward)
      final distance = maxDistance * easedProgress * particle.speed;
      final x = centerX + math.cos(particle.angle) * distance;
      final y = centerY + math.sin(particle.angle) * distance;

      // Perspective scaling (particles get bigger as they "approach")
      final perspectiveScale = 1 + easedProgress * 3 * particle.z;
      final currentSize = particle.size * perspectiveScale;

      // Opacity fades at the end
      final opacity = (1 - easedProgress * 0.8).clamp(0.0, 1.0);

      // Motion blur effect
      final blurOffset = easedProgress * 20 * particle.speed;
      final blurX = math.cos(particle.angle) * blurOffset;
      final blurY = math.sin(particle.angle) * blurOffset;

      final paint = Paint()
        ..color = particle.color.withValues(alpha: opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, currentSize * 0.3);

      // Draw particle with motion blur trail
      for (var i = 0; i < 3; i++) {
        final trailFactor = i / 3;
        final trailX = x - blurX * trailFactor;
        final trailY = y - blurY * trailFactor;
        final trailOpacity = opacity * (1 - trailFactor * 0.5);

        canvas.drawCircle(
          Offset(trailX, trailY),
          currentSize * (1 - trailFactor * 0.3),
          Paint()..color = particle.color.withValues(alpha: trailOpacity),
        );
      }

      // Main particle
      canvas.drawCircle(Offset(x, y), currentSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticleExplosionPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
