import 'dart:math' as math;

import 'package:flutter/material.dart' hide Easing;

import '../../presentation/time_consumer.dart';
import '../../presentation/video_composition.dart';
import '../../declarative/utils/easing.dart';
import '../../declarative/animations/core/animated_prop.dart';
import '../../declarative/animations/core/prop_animation.dart';
import '../../declarative/effects/particle_effect.dart';
import '../../declarative/helpers/floating_element.dart';
import '../_base/template_base.dart';
import '../_base/template_config.dart';
import '../_base/template_data.dart';

/// A central portal of glowing rings with text sliding through the center.
///
/// Creates a dramatic intro effect with concentric animated rings that
/// pulse and glow, while the title text appears to slide through the
/// portal toward the viewer.
///
/// Best used for:
/// - Year intro ("Your 2024")
/// - Brand reveals
/// - Dramatic openings
///
/// Example:
/// ```dart
/// TheNeonGate(
///   data: IntroData(
///     title: 'Your 2024',
///     subtitle: 'Wrapped',
///     year: 2024,
///   ),
///   theme: TemplateTheme.neon,
/// )
/// ```
class TheNeonGate extends WrappedTemplate with TemplateAnimationMixin {
  /// Number of concentric rings in the portal.
  final int ringCount;

  /// Whether to include particle effects.
  final bool showParticles;

  /// Whether to animate ring rotation.
  final bool animateRotation;

  const TheNeonGate({
    super.key,
    required IntroData super.data,
    super.theme,
    super.timing,
    this.ringCount = 5,
    this.showParticles = true,
    this.animateRotation = true,
  });

  @override
  int get recommendedLength => 150;

  @override
  TemplateCategory get category => TemplateCategory.intro;

  @override
  String get description =>
      'A central portal of glowing rings with text sliding through the center';

  @override
  TemplateTheme get defaultTheme => TemplateTheme.neon;

  @override
  TemplateTiming get defaultTiming => TemplateTiming.dramatic;

  IntroData get introData => data as IntroData;

  @override
  Widget build(BuildContext context) {
    final colors = effectiveTheme;
    final timing = effectiveTiming;

    return Container(
      color: colors.backgroundColor,
      child: Stack(
        children: [
          // Particle background
          if (showParticles)
            Positioned.fill(
              child: ParticleEffect.sparkles(
                count: 30,
                color: colors.primaryColor.withValues(alpha: 0.5),
              ),
            ),

          // Portal rings
          Positioned.fill(child: Center(child: _buildPortalRings(colors))),

          // Main content
          Positioned.fill(child: Center(child: _buildContent(colors, timing))),
        ],
      ),
    );
  }

  Widget _buildPortalRings(TemplateTheme colors) {
    return TimeConsumer(
      builder: (context, frame, _) {
        final composition = VideoComposition.of(context);
        final fps = composition?.fps ?? 30;
        final time = frame / fps;

        return Stack(
          alignment: Alignment.center,
          children: List.generate(ringCount, (index) {
            final ringIndex = ringCount - 1 - index; // Outer rings first
            final baseSize = 200.0 + (ringIndex * 120);

            // Pulsing animation
            final pulsePhase = index * 0.4;
            final pulseScale = 1.0 + math.sin(time * 2 + pulsePhase) * 0.05;

            // Entry animation - rings expand from center
            final entryDuration = 40.0;
            final entryDelay = index * 5.0;
            final entryProgress = ((frame - entryDelay) / entryDuration).clamp(
              0.0,
              1.0,
            );
            final easedEntry = Curves.easeOutCubic.transform(entryProgress);
            final entryScale = easedEntry;

            // Rotation (outer rings rotate faster)
            final rotationSpeed = animateRotation ? (index + 1) * 0.1 : 0.0;
            final rotation = time * rotationSpeed;

            // Opacity based on entry
            final opacity = (easedEntry * 0.7).clamp(0.0, 1.0);

            return Transform.rotate(
              angle: rotation,
              child: Transform.scale(
                scale: entryScale * pulseScale,
                child: Container(
                  width: baseSize,
                  height: baseSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.primaryColor.withValues(alpha: opacity),
                      width: 3 - (index * 0.3).clamp(0.0, 2.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primaryColor.withValues(
                          alpha: opacity * 0.5,
                        ),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                      BoxShadow(
                        color: colors.secondaryColor.withValues(
                          alpha: opacity * 0.3,
                        ),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildContent(TemplateTheme colors, TemplateTiming timing) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo if provided
        if (introData.logoPath != null) ...[
          AnimatedProp(
            startFrame: 30,
            duration: 40,
            animation: PropAnimation.combine([
              PropAnimation.zoomIn(start: 0.3),
              PropAnimation.fadeIn(),
            ]),
            curve: Easing.easeOutBack,
            child: Image.asset(
              introData.logoPath!,
              width: 120,
              height: 120,
              errorBuilder: (_, __, ___) => Icon(
                Icons.auto_awesome,
                size: 80,
                color: colors.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],

        // Main title - slides through portal
        AnimatedProp(
          startFrame: 45,
          duration: 50,
          animation: PropAnimation.combine([
            PropAnimation.translate(
              start: const Offset(0, 100),
              end: Offset.zero,
            ),
            PropAnimation.scale(start: 0.5, end: 1.0),
            PropAnimation.fadeIn(),
          ]),
          curve: Easing.easeOutCubic,
          child: FloatingElement(
            floatAmplitude: const Offset(0, 5),
            floatFrequency: 0.3,
            child: _buildGlowingText(
              introData.title,
              colors,
              fontSize: 80,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),

        // Year if provided
        if (introData.year != null) ...[
          const SizedBox(height: 20),
          AnimatedProp(
            startFrame: 70,
            duration: 40,
            animation: PropAnimation.combine([
              PropAnimation.zoomIn(start: 0.1),
              PropAnimation.fadeIn(),
            ]),
            curve: Easing.elastic,
            child: FloatingElement(
              floatAmplitude: const Offset(0, 3),
              floatFrequency: 0.4,
              floatPhase: 0.5,
              child: _buildGlowingText(
                '${introData.year}',
                colors,
                fontSize: 120,
                fontWeight: FontWeight.w900,
                letterSpacing: 15,
              ),
            ),
          ),
        ],

        // Subtitle if provided
        if (introData.subtitle != null) ...[
          const SizedBox(height: 25),
          AnimatedProp(
            startFrame: 90,
            duration: 30,
            animation: PropAnimation.slideUpFade(distance: 30),
            curve: Easing.easeOutBack,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              decoration: BoxDecoration(
                color: colors.primaryColor,
                borderRadius: BorderRadius.circular(50),
                boxShadow: [
                  BoxShadow(
                    color: colors.primaryColor.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Text(
                introData.subtitle!.toUpperCase(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: colors.backgroundColor,
                  letterSpacing: 6,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGlowingText(
    String text,
    TemplateTheme colors, {
    double fontSize = 64,
    FontWeight fontWeight = FontWeight.w700,
    double letterSpacing = 0,
  }) {
    return Stack(
      children: [
        // Glow layer
        Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: colors.primaryColor.withValues(alpha: 0.5),
            letterSpacing: letterSpacing,
            shadows: [
              Shadow(color: colors.primaryColor, blurRadius: 30),
              Shadow(color: colors.secondaryColor, blurRadius: 60),
            ],
          ),
        ),
        // Main text
        Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: colors.textColor,
            letterSpacing: letterSpacing,
          ),
        ),
      ],
    );
  }
}
