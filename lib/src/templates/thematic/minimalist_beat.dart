import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../presentation/time_consumer.dart';
import '../../presentation/video_composition.dart';
import '../../declarative/animations/core/animated_prop.dart';
import '../../declarative/animations/core/prop_animation.dart';
import '../_base/template_base.dart';
import '../_base/template_config.dart';
import '../_base/template_data.dart';

/// Two-color minimalist typography synced to a beat.
///
/// Creates a stark, high-contrast design using only two colors
/// with bold typography that pulses or animates to a beat.
/// Clean, modern, and impactful.
///
/// Best used for:
/// - Bold stat reveals
/// - Minimalist aesthetics
/// - Typography-focused content
///
/// Example:
/// ```dart
/// MinimalistBeat(
///   data: ThematicData(
///     title: '1,234',
///     subtitle: 'hours listened',
///   ),
///   bpm: 120,
/// )
/// ```
class MinimalistBeat extends WrappedTemplate with TemplateAnimationMixin {
  /// Beats per minute for animation sync.
  final int bpm;

  /// Primary color for the design.
  final Color? primaryColor;

  /// Secondary color for the design.
  final Color? secondaryColor;

  /// Whether text pulses on beat.
  final bool pulseOnBeat;

  /// Whether to invert colors on beat.
  final bool invertOnBeat;

  const MinimalistBeat({
    super.key,
    required ThematicData super.data,
    super.theme,
    super.timing,
    this.bpm = 120,
    this.primaryColor,
    this.secondaryColor,
    this.pulseOnBeat = true,
    this.invertOnBeat = false,
  });

  @override
  int get recommendedLength => 150;

  @override
  TemplateCategory get category => TemplateCategory.thematic;

  @override
  String get description => 'Two-color typography synced to beat';

  @override
  TemplateTheme get defaultTheme => TemplateTheme.minimal;

  ThematicData get thematicData => data as ThematicData;

  @override
  Widget build(BuildContext context) {
    final colors = effectiveTheme;
    final color1 = primaryColor ?? colors.backgroundColor;
    final color2 = secondaryColor ?? colors.textColor;

    return TimeConsumer(
      builder: (context, frame, _) {
        final composition = VideoComposition.of(context);
        final fps = composition?.fps ?? 30;

        // Calculate beat timing
        final beatsPerSecond = bpm / 60.0;
        final framesPerBeat = fps / beatsPerSecond;
        final beatPhase = (frame % framesPerBeat) / framesPerBeat;
        final isOnBeat = beatPhase < 0.1;

        // Invert colors on beat if enabled
        final bgColor = (invertOnBeat && isOnBeat) ? color2 : color1;
        final fgColor = (invertOnBeat && isOnBeat) ? color1 : color2;

        // Pulse scale on beat
        final pulseScale = pulseOnBeat
            ? 1.0 + (isOnBeat ? 0.05 : 0.0) * math.sin(beatPhase * math.pi)
            : 1.0;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 50),
          color: bgColor,
          child: Center(
            child: Transform.scale(
              scale: pulseScale,
              child: _buildContent(fgColor, bgColor, frame),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(Color foreground, Color background, int frame) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main number/title
        AnimatedProp(
          startFrame: 20,
          duration: 40,
          animation: PropAnimation.combine([
            PropAnimation.scale(start: 0.5, end: 1.0),
            PropAnimation.fadeIn(),
          ]),
          child: Text(
            thematicData.title ?? '0',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 160,
              fontWeight: FontWeight.w900,
              color: foreground,
              height: 0.9,
              letterSpacing: -8,
            ),
          ),
        ),

        // Subtitle
        if (thematicData.subtitle != null) ...[
          const SizedBox(height: 20),
          AnimatedProp(
            startFrame: 50,
            duration: 30,
            animation: PropAnimation.fadeIn(),
            child: Text(
              thematicData.subtitle!.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: foreground.withValues(alpha: 0.7),
                letterSpacing: 12,
              ),
            ),
          ),
        ],

        // Description
        if (thematicData.description != null) ...[
          const SizedBox(height: 40),
          AnimatedProp(
            startFrame: 80,
            duration: 30,
            animation: PropAnimation.slideUpFade(distance: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              decoration: BoxDecoration(
                border: Border.all(color: foreground, width: 2),
              ),
              child: Text(
                thematicData.description!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: foreground,
                ),
              ),
            ),
          ),
        ],

        // Beat indicator
        const SizedBox(height: 50),
        _buildBeatIndicator(foreground, frame),
      ],
    );
  }

  Widget _buildBeatIndicator(Color color, int frame) {
    return TimeConsumer(
      builder: (context, frame, _) {
        final composition = VideoComposition.of(context);
        final fps = composition?.fps ?? 30;

        final beatsPerSecond = bpm / 60.0;
        final framesPerBeat = fps / beatsPerSecond;

        // 4 beat indicators
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(4, (index) {
            final beatInMeasure = ((frame / framesPerBeat).floor() % 4);
            final isCurrentBeat = index == beatInMeasure;
            final size = isCurrentBeat ? 12.0 : 8.0;
            final opacity = isCurrentBeat ? 1.0 : 0.3;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: opacity),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
