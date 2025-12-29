import 'dart:math' as math;
import 'dart:ui';

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

/// A blurred video background with a high-contrast profile cutout that "breathes".
///
/// Creates a mirror-like effect where the user's profile image appears
/// as a sharp cutout against a blurred, dreamlike background. The cutout
/// subtly pulses creating a "breathing" effect.
///
/// Best used for:
/// - Personalized intros
/// - Profile reveals
/// - Self-reflection moments
///
/// Example:
/// ```dart
/// DigitalMirror(
///   data: IntroData(
///     title: 'Your Story',
///     userName: 'John',
///     profileImagePath: 'assets/profile.jpg',
///   ),
///   theme: TemplateTheme.midnight,
/// )
/// ```
class DigitalMirror extends WrappedTemplate with TemplateAnimationMixin {
  /// Blur intensity for the background.
  final double blurIntensity;

  /// Whether to show the breathing pulse effect.
  final bool showBreathing;

  /// Shape of the profile cutout.
  final ProfileShape profileShape;

  const DigitalMirror({
    super.key,
    required IntroData super.data,
    super.theme,
    super.timing,
    this.blurIntensity = 20.0,
    this.showBreathing = true,
    this.profileShape = ProfileShape.circle,
  });

  @override
  int get recommendedLength => 150;

  @override
  TemplateCategory get category => TemplateCategory.intro;

  @override
  String get description =>
      'A blurred background with a breathing profile cutout effect';

  @override
  TemplateTheme get defaultTheme => TemplateTheme.midnight;

  IntroData get introData => data as IntroData;

  @override
  Widget build(BuildContext context) {
    final colors = effectiveTheme;

    return Container(
      color: colors.backgroundColor,
      child: Stack(
        children: [
          // Blurred background
          Positioned.fill(child: _buildBlurredBackground(colors)),

          // Particle overlay
          Positioned.fill(
            child: ParticleEffect.sparkles(
              count: 20,
              color: colors.accentColor.withValues(alpha: 0.4),
            ),
          ),

          // Profile cutout
          Positioned.fill(child: Center(child: _buildProfileCutout(colors))),

          // Text content
          Positioned.fill(child: _buildTextContent(colors)),
        ],
      ),
    );
  }

  Widget _buildBlurredBackground(TemplateTheme colors) {
    return TimeConsumer(
      builder: (context, frame, _) {
        final entryProgress = calculateEntryProgress(frame, 0, 30);

        return AnimatedOpacity(
          opacity: entryProgress,
          duration: Duration.zero,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: blurIntensity,
              sigmaY: blurIntensity,
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.primaryColor.withValues(alpha: 0.3),
                    colors.secondaryColor.withValues(alpha: 0.3),
                    colors.backgroundColor,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileCutout(TemplateTheme colors) {
    return TimeConsumer(
      builder: (context, frame, _) {
        final composition = VideoComposition.of(context);
        final fps = composition?.fps ?? 30;
        final time = frame / fps;

        // Entry animation
        final entryProgress = calculateEntryProgress(frame, 20, 45);
        final easedEntry = Curves.easeOutBack.transform(entryProgress);

        // Breathing effect
        double breathingScale = 1.0;
        if (showBreathing && entryProgress > 0.5) {
          breathingScale = 1.0 + math.sin(time * 1.5) * 0.02;
        }

        // Glow intensity follows breathing
        final glowIntensity = showBreathing
            ? 0.3 + math.sin(time * 1.5) * 0.1
            : 0.3;

        final size = 280.0 * easedEntry * breathingScale;

        Widget profileWidget;

        if (introData.profileImagePath != null) {
          profileWidget = ClipPath(
            clipper: _ProfileShapeClipper(profileShape),
            child: Image.asset(
              introData.profileImagePath!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _buildPlaceholderProfile(size, colors),
            ),
          );
        } else {
          profileWidget = _buildPlaceholderProfile(size, colors);
        }

        return Container(
          width: size + 20,
          height: size + 20,
          decoration: BoxDecoration(
            shape: profileShape == ProfileShape.circle
                ? BoxShape.circle
                : BoxShape.rectangle,
            boxShadow: [
              BoxShadow(
                color: colors.primaryColor.withValues(alpha: glowIntensity),
                blurRadius: 40,
                spreadRadius: 10,
              ),
              BoxShadow(
                color: colors.secondaryColor.withValues(
                  alpha: glowIntensity * 0.5,
                ),
                blurRadius: 80,
                spreadRadius: 20,
              ),
            ],
          ),
          child: Center(child: profileWidget),
        );
      },
    );
  }

  Widget _buildPlaceholderProfile(double size, TemplateTheme colors) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: profileShape == ProfileShape.circle
            ? BoxShape.circle
            : BoxShape.rectangle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primaryColor, colors.secondaryColor],
        ),
      ),
      child: Icon(
        Icons.person,
        size: size * 0.5,
        color: colors.textColor.withValues(alpha: 0.8),
      ),
    );
  }

  Widget _buildTextContent(TemplateTheme colors) {
    return Column(
      children: [
        const Spacer(flex: 3),

        // Username if provided
        if (introData.userName != null)
          AnimatedProp(
            startFrame: 50,
            duration: 35,
            animation: PropAnimation.slideUpFade(distance: 30),
            curve: Easing.easeOutCubic,
            child: Text(
              'Hey, ${introData.userName}',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w400,
                color: colors.textColor.withValues(alpha: 0.8),
              ),
            ),
          ),

        const SizedBox(height: 16),

        // Main title
        AnimatedProp(
          startFrame: 70,
          duration: 40,
          animation: PropAnimation.combine([
            PropAnimation.zoomIn(start: 0.8),
            PropAnimation.fadeIn(),
          ]),
          curve: Easing.easeOutBack,
          child: Text(
            introData.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 52,
              fontWeight: FontWeight.w800,
              color: colors.textColor,
              letterSpacing: 2,
            ),
          ),
        ),

        // Subtitle
        if (introData.subtitle != null) ...[
          const SizedBox(height: 12),
          AnimatedProp(
            startFrame: 90,
            duration: 30,
            animation: PropAnimation.slideUpFade(distance: 20),
            child: Text(
              introData.subtitle!,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w300,
                color:
                    colors.mutedColor ??
                    colors.textColor.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],

        const Spacer(flex: 1),
      ],
    );
  }
}

/// Shape options for the profile cutout.
enum ProfileShape { circle, roundedSquare, hexagon }

/// Custom clipper for profile shapes.
class _ProfileShapeClipper extends CustomClipper<Path> {
  final ProfileShape shape;

  _ProfileShapeClipper(this.shape);

  @override
  Path getClip(Size size) {
    switch (shape) {
      case ProfileShape.circle:
        return Path()..addOval(Rect.fromLTWH(0, 0, size.width, size.height));
      case ProfileShape.roundedSquare:
        return Path()..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, size.width, size.height),
            const Radius.circular(30),
          ),
        );
      case ProfileShape.hexagon:
        return _createHexagonPath(size);
    }
  }

  Path _createHexagonPath(Size size) {
    final path = Path();
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = math.min(cx, cy);

    for (var i = 0; i < 6; i++) {
      final angle = (i * math.pi / 3) - math.pi / 6;
      final x = cx + radius * math.cos(angle);
      final y = cy + radius * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
