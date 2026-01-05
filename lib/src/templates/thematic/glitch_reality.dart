import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../presentation/time_consumer.dart';
import '../../declarative/animations/core/animated_prop.dart';
import '../../declarative/animations/core/prop_animation.dart';
import '../_base/template_base.dart';
import '../_base/template_config.dart';
import '../_base/template_data.dart';

/// VHS screen that "breaks" on beat to reveal hidden stats.
///
/// Creates a retro VHS glitch effect where the screen distorts and
/// breaks apart to reveal hidden information. The effect intensifies
/// at key moments, simulating digital corruption.
///
/// Best used for:
/// - Hidden stats reveals
/// - Surprise moments
/// - Retro/synthwave vibes
///
/// Example:
/// ```dart
/// GlitchReality(
///   data: ThematicData(
///     title: 'Hidden Gem',
///     subtitle: 'A song you discovered',
///     value: 'Midnight Rain',
///   ),
/// )
/// ```
class GlitchReality extends WrappedTemplate with TemplateAnimationMixin {
  /// Intensity of the glitch effect.
  final double glitchIntensity;

  /// Show VHS scanlines.
  final bool showScanlines;

  /// Show RGB chromatic aberration.
  final bool showChromatic;

  /// Frames where glitches occur.
  final List<int>? glitchFrames;

  /// Random seed.
  final int seed;

  const GlitchReality({
    super.key,
    required ThematicData super.data,
    super.theme,
    super.timing,
    this.glitchIntensity = 0.8,
    this.showScanlines = true,
    this.showChromatic = true,
    this.glitchFrames,
    this.seed = 42,
  });

  @override
  int get recommendedLength => 150;

  @override
  TemplateCategory get category => TemplateCategory.thematic;

  @override
  String get description => 'VHS screen that breaks to reveal hidden stats';

  @override
  TemplateTheme get defaultTheme => TemplateTheme.retro;

  ThematicData get thematicData => data as ThematicData;

  List<int> get effectiveGlitchFrames => glitchFrames ?? [30, 60, 90, 110];

  @override
  Widget build(BuildContext context) {
    final colors = effectiveTheme;

    return Container(
      color: colors.backgroundColor,
      child: Stack(
        children: [
          // Hidden content (revealed during glitches)
          Positioned.fill(child: _buildHiddenContent(colors)),

          // VHS overlay content
          Positioned.fill(child: _buildVHSContent(colors)),

          // Scanlines
          if (showScanlines) Positioned.fill(child: _buildScanlines(colors)),

          // Glitch effects
          Positioned.fill(child: _buildGlitchOverlay(colors)),
        ],
      ),
    );
  }

  Widget _buildHiddenContent(TemplateTheme colors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.accentColor, colors.primaryColor],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (thematicData.value != null)
              Text(
                '${thematicData.value}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  color: colors.textColor,
                ),
              ),
            if (thematicData.subtitle != null) ...[
              const SizedBox(height: 16),
              Text(
                thematicData.subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  color: colors.textColor.withValues(alpha: 0.8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVHSContent(TemplateTheme colors) {
    return TimeConsumer(
      builder: (context, frame, _) {
        // Calculate if we're in a glitch moment
        final isGlitching = _isGlitching(frame);
        final glitchProgress = _getGlitchProgress(frame);

        // During glitch, content becomes distorted/transparent
        final opacity = isGlitching ? (1.0 - glitchProgress * 0.8) : 1.0;

        return Opacity(
          opacity: opacity,
          child: Container(
            color: colors.backgroundColor,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Static/noise text effect
                  AnimatedProp(
                    startFrame: 10,
                    duration: 30,
                    animation: PropAnimation.fadeIn(),
                    child: Text(
                      'PLAY',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: colors.textColor.withValues(alpha: 0.6),
                        letterSpacing: 4,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),

                  // Title with VHS styling
                  Text(
                    thematicData.title ?? 'LOADING...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      color: colors.textColor,
                      letterSpacing: 6,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // VHS timestamp
                  Text(
                    _formatVHSTime(frame),
                    style: TextStyle(
                      fontSize: 18,
                      color: colors.primaryColor,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScanlines(TemplateTheme colors) {
    return TimeConsumer(
      builder: (context, frame, _) {
        return CustomPaint(
          painter: _ScanlinePainter(
            frame: frame,
            color: Colors.black.withValues(alpha: 0.1),
          ),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildGlitchOverlay(TemplateTheme colors) {
    return TimeConsumer(
      builder: (context, frame, _) {
        final isGlitching = _isGlitching(frame);

        if (!isGlitching) {
          return const SizedBox.shrink();
        }

        return CustomPaint(
          painter: _GlitchPainter(
            frame: frame,
            intensity: glitchIntensity,
            showChromatic: showChromatic,
            seed: seed,
          ),
          size: Size.infinite,
        );
      },
    );
  }

  bool _isGlitching(int frame) {
    for (final glitchFrame in effectiveGlitchFrames) {
      if (frame >= glitchFrame && frame < glitchFrame + 15) {
        return true;
      }
    }
    return false;
  }

  double _getGlitchProgress(int frame) {
    for (final glitchFrame in effectiveGlitchFrames) {
      if (frame >= glitchFrame && frame < glitchFrame + 15) {
        final progress = (frame - glitchFrame) / 15.0;
        // Peak in middle
        return math.sin(progress * math.pi);
      }
    }
    return 0.0;
  }

  String _formatVHSTime(int frame) {
    final totalSeconds = frame ~/ 30;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final frames = frame % 30;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}:${frames.toString().padLeft(2, '0')}';
  }
}

class _ScanlinePainter extends CustomPainter {
  final int frame;
  final Color color;

  _ScanlinePainter({required this.frame, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const lineHeight = 2.0;
    const gap = 4.0;

    for (var y = 0.0; y < size.height; y += lineHeight + gap) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, lineHeight), paint);
    }

    // Moving scan line
    final scanY = (frame * 3.0) % size.height;
    canvas.drawRect(
      Rect.fromLTWH(0, scanY, size.width, 8),
      Paint()..color = Colors.white.withValues(alpha: 0.05),
    );
  }

  @override
  bool shouldRepaint(covariant _ScanlinePainter oldDelegate) {
    return oldDelegate.frame != frame;
  }
}

class _GlitchPainter extends CustomPainter {
  final int frame;
  final double intensity;
  final bool showChromatic;
  final int seed;

  _GlitchPainter({
    required this.frame,
    required this.intensity,
    required this.showChromatic,
    required this.seed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed + frame);

    // Horizontal slice displacement
    final sliceCount = (10 * intensity).toInt();
    for (var i = 0; i < sliceCount; i++) {
      final y = random.nextDouble() * size.height;
      final height = 5 + random.nextDouble() * 30;
      final offset = (random.nextDouble() - 0.5) * 50 * intensity;

      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, y, size.width, height));
      canvas.translate(offset, 0);

      // Draw colored rectangles for glitch effect
      if (showChromatic) {
        canvas.drawRect(
          Rect.fromLTWH(-offset, y, size.width, height),
          Paint()..color = Colors.cyan.withValues(alpha: 0.3),
        );
        canvas.drawRect(
          Rect.fromLTWH(offset, y, size.width, height),
          Paint()..color = Colors.red.withValues(alpha: 0.3),
        );
      }

      canvas.restore();
    }

    // Random noise blocks
    final noiseCount = (20 * intensity).toInt();
    for (var i = 0; i < noiseCount; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final w = 10 + random.nextDouble() * 50;
      final h = 5 + random.nextDouble() * 20;

      canvas.drawRect(
        Rect.fromLTWH(x, y, w, h),
        Paint()
          ..color = (random.nextBool() ? Colors.white : Colors.black)
              .withValues(alpha: random.nextDouble() * 0.5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GlitchPainter oldDelegate) {
    return oldDelegate.frame != frame;
  }
}
