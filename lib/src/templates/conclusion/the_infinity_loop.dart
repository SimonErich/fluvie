import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../presentation/time_consumer.dart';
import '../../declarative/animations/core/animated_prop.dart';
import '../../declarative/animations/core/prop_animation.dart';
import '../_base/template_base.dart';
import '../_base/template_config.dart';
import '../_base/template_data.dart';

/// Last frame matches first for seamless social media loops.
///
/// Creates a conclusion that seamlessly connects back to the beginning
/// of the video, making it perfect for social media loops. The ending
/// morphs into what could be the start of a new viewing.
///
/// Best used for:
/// - Social media content
/// - Loop-friendly endings
/// - Continuous viewing experiences
///
/// Example:
/// ```dart
/// TheInfinityLoop(
///   data: SummaryData(
///     title: 'See You Next Year',
///     subtitle: 'Play Again?',
///   ),
///   loopStyle: LoopStyle.zoom,
/// )
/// ```
class TheInfinityLoop extends WrappedTemplate with TemplateAnimationMixin {
  /// Style of the loop transition.
  final LoopStyle loopStyle;

  /// Color that the scene fades/transitions to.
  final Color? transitionColor;

  /// Whether to show a "replay" icon.
  final bool showReplayIcon;

  const TheInfinityLoop({
    super.key,
    required SummaryData super.data,
    super.theme,
    super.timing,
    this.loopStyle = LoopStyle.zoom,
    this.transitionColor,
    this.showReplayIcon = true,
  });

  @override
  int get recommendedLength => 180;

  @override
  TemplateCategory get category => TemplateCategory.conclusion;

  @override
  String get description => 'Last frame matches first for loops';

  @override
  TemplateTheme get defaultTheme => TemplateTheme.spotify;

  SummaryData get summaryData => data as SummaryData;

  @override
  Widget build(BuildContext context) {
    final colors = effectiveTheme;
    final loopColor = transitionColor ?? colors.backgroundColor;

    return TimeConsumer(
      builder: (context, frame, _) {
        // Phase calculations
        // Phase 1: Content display (frames 0-120)
        // Phase 2: Loop transition (frames 120-180)
        const loopStartFrame = 120;
        final loopProgress = ((frame - loopStartFrame) / 60).clamp(0.0, 1.0);

        return Container(
          color: loopColor,
          child: Stack(
            children: [
              // Main content
              Positioned.fill(
                child: _buildMainContent(colors, frame, loopProgress),
              ),

              // Loop transition overlay
              if (loopProgress > 0)
                Positioned.fill(
                  child: _buildLoopTransition(colors, loopProgress),
                ),

              // Replay icon
              if (showReplayIcon && loopProgress > 0.5)
                Positioned.fill(
                  child: Center(child: _buildReplayIcon(colors, loopProgress)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainContent(
    TemplateTheme colors,
    int frame,
    double loopProgress,
  ) {
    // Content fades/transforms as loop approaches
    final contentOpacity = (1.0 - loopProgress).clamp(0.0, 1.0);
    final contentScale = 1.0 + (loopProgress * _getScaleMultiplier());

    return Transform.scale(
      scale: contentScale,
      child: Opacity(
        opacity: contentOpacity,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main title
              AnimatedProp(
                startFrame: 20,
                duration: 40,
                animation: PropAnimation.combine([
                  const PropAnimation.scale(start: 0.9, end: 1.0),
                  PropAnimation.fadeIn(),
                ]),
                child: Text(
                  summaryData.title ?? 'See You Next Year',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    color: colors.textColor,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Subtitle
              if (summaryData.subtitle != null)
                AnimatedProp(
                  startFrame: 50,
                  duration: 30,
                  animation: PropAnimation.slideUpFade(distance: 20),
                  child: Text(
                    summaryData.subtitle!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      color: colors.textColor.withValues(alpha: 0.7),
                    ),
                  ),
                ),

              const SizedBox(height: 50),

              // Year/name
              AnimatedProp(
                startFrame: 70,
                duration: 30,
                animation: PropAnimation.fadeIn(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.primaryColor, width: 2),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (summaryData.name != null) ...[
                        Text(
                          summaryData.name!,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: colors.textColor,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 20,
                          color: colors.primaryColor.withValues(alpha: 0.5),
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ],
                      Text(
                        summaryData.year?.toString() ??
                            DateTime.now().year.toString(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: colors.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoopTransition(TemplateTheme colors, double progress) {
    switch (loopStyle) {
      case LoopStyle.zoom:
        return _buildZoomTransition(colors, progress);
      case LoopStyle.fade:
        return _buildFadeTransition(colors, progress);
      case LoopStyle.spiral:
        return _buildSpiralTransition(colors, progress);
      case LoopStyle.wipe:
        return _buildWipeTransition(colors, progress);
    }
  }

  Widget _buildZoomTransition(TemplateTheme colors, double progress) {
    final scale = 1.0 + progress * 5;
    final opacity = progress;

    return Transform.scale(
      scale: scale,
      child: Container(
        color: (transitionColor ?? colors.backgroundColor).withValues(
          alpha: opacity,
        ),
      ),
    );
  }

  Widget _buildFadeTransition(TemplateTheme colors, double progress) {
    return Container(
      color: (transitionColor ?? colors.backgroundColor).withValues(
        alpha: progress,
      ),
    );
  }

  Widget _buildSpiralTransition(TemplateTheme colors, double progress) {
    final rotation = progress * math.pi * 4;
    final scale = 1.0 + progress * 3;

    return Transform.rotate(
      angle: rotation,
      child: Transform.scale(
        scale: scale,
        child: Container(
          color: (transitionColor ?? colors.backgroundColor).withValues(
            alpha: progress,
          ),
        ),
      ),
    );
  }

  Widget _buildWipeTransition(TemplateTheme colors, double progress) {
    return ClipPath(
      clipper: _CircularWipeClipper(progress: progress),
      child: Container(color: transitionColor ?? colors.backgroundColor),
    );
  }

  Widget _buildReplayIcon(TemplateTheme colors, double progress) {
    final iconProgress = ((progress - 0.5) / 0.5).clamp(0.0, 1.0);
    final scale = Curves.easeOutBack.transform(iconProgress);
    final opacity = iconProgress;

    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.primaryColor,
            boxShadow: [
              BoxShadow(
                color: colors.primaryColor.withValues(alpha: 0.5),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Icon(Icons.replay, size: 50, color: colors.backgroundColor),
        ),
      ),
    );
  }

  double _getScaleMultiplier() {
    switch (loopStyle) {
      case LoopStyle.zoom:
        return 2.0;
      case LoopStyle.fade:
        return 0.1;
      case LoopStyle.spiral:
        return 1.0;
      case LoopStyle.wipe:
        return 0.0;
    }
  }
}

/// Loop transition styles.
enum LoopStyle { zoom, fade, spiral, wipe }

class _CircularWipeClipper extends CustomClipper<Path> {
  final double progress;

  _CircularWipeClipper({required this.progress});

  @override
  Path getClip(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius =
        math.sqrt(size.width * size.width + size.height * size.height) / 2;
    final currentRadius = maxRadius * progress;

    return Path()
      ..addOval(Rect.fromCircle(center: center, radius: currentRadius));
  }

  @override
  bool shouldReclip(covariant _CircularWipeClipper oldClipper) {
    return oldClipper.progress != progress;
  }
}
