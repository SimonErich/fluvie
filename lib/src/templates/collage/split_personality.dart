import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../presentation/time_consumer.dart';
import '../../declarative/animations/core/animated_prop.dart';
import '../../declarative/animations/core/prop_animation.dart';
import '../_base/template_base.dart';
import '../_base/template_config.dart';
import '../_base/template_data.dart';

/// Diagonal split with video/image on one side and kinetic typography on the other.
///
/// Creates a dynamic split-screen effect where one half shows an image or color
/// while the other half displays animated text. The split can be diagonal,
/// horizontal, or vertical with animated transitions.
///
/// Best used for:
/// - Artist features
/// - Quote displays
/// - Before/after comparisons
///
/// Example:
/// ```dart
/// SplitPersonality(
///   data: CollageData(
///     title: 'Top Artist',
///     subtitle: 'Taylor Swift',
///     images: ['taylor.jpg'],
///     description: '1,234 hours listened',
///   ),
///   splitAngle: 15,
/// )
/// ```
class SplitPersonality extends WrappedTemplate with TemplateAnimationMixin {
  /// Angle of the diagonal split (0 = vertical, 90 = horizontal).
  final double splitAngle;

  /// Which side shows the image (true = left/top).
  final bool imageOnLeft;

  /// Animation style for the text.
  final TextAnimationStyle textAnimation;

  const SplitPersonality({
    super.key,
    required CollageData super.data,
    super.theme,
    super.timing,
    this.splitAngle = 15,
    this.imageOnLeft = true,
    this.textAnimation = TextAnimationStyle.typewriter,
  });

  @override
  int get recommendedLength => 180;

  @override
  TemplateCategory get category => TemplateCategory.collage;

  @override
  String get description => 'Diagonal split with image and kinetic typography';

  @override
  TemplateTheme get defaultTheme => TemplateTheme.midnight;

  CollageData get collageData => data as CollageData;

  @override
  Widget build(BuildContext context) {
    final colors = effectiveTheme;

    return Container(
      color: colors.backgroundColor,
      child: Stack(
        children: [
          // Image side
          Positioned.fill(child: _buildImageSide(colors)),

          // Text side with clip
          Positioned.fill(child: _buildTextSide(colors)),

          // Split line decoration
          Positioned.fill(child: _buildSplitLine(colors)),
        ],
      ),
    );
  }

  Widget _buildImageSide(TemplateTheme colors) {
    return TimeConsumer(
      builder: (context, frame, _) {
        final entryProgress = ((frame - 10) / 40).clamp(0.0, 1.0);
        final slideOffset = (1 - Curves.easeOutCubic.transform(entryProgress)) *
            (imageOnLeft ? -200 : 200);

        return Transform.translate(
          offset: Offset(slideOffset, 0),
          child: ClipPath(
            clipper: _DiagonalClipper(angle: splitAngle, isLeft: imageOnLeft),
            child: Container(
              decoration: BoxDecoration(color: colors.primaryColor),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image or gradient
                  if (collageData.images.isNotEmpty)
                    Image.asset(
                      collageData.images.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildImageGradient(colors),
                    )
                  else
                    _buildImageGradient(colors),

                  // Subtle overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: imageOnLeft
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        end: imageOnLeft
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        colors: [
                          Colors.black.withValues(alpha: 0.4),
                          Colors.transparent,
                        ],
                      ),
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

  Widget _buildImageGradient(TemplateTheme colors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primaryColor, colors.secondaryColor],
        ),
      ),
    );
  }

  Widget _buildTextSide(TemplateTheme colors) {
    return TimeConsumer(
      builder: (context, frame, _) {
        final entryProgress = ((frame - 30) / 40).clamp(0.0, 1.0);
        final slideOffset = (1 - Curves.easeOutCubic.transform(entryProgress)) *
            (imageOnLeft ? 200 : -200);

        return Transform.translate(
          offset: Offset(slideOffset, 0),
          child: ClipPath(
            clipper: _DiagonalClipper(angle: splitAngle, isLeft: !imageOnLeft),
            child: Container(
              color: colors.backgroundColor,
              child: _buildTextContent(colors, frame),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextContent(TemplateTheme colors, int frame) {
    return Padding(
      padding: EdgeInsets.only(
        left: imageOnLeft ? 100 : 60,
        right: imageOnLeft ? 60 : 100,
        top: 120,
        bottom: 80,
      ),
      child: Column(
        crossAxisAlignment:
            imageOnLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Title
          AnimatedProp(
            startFrame: 50,
            duration: 35,
            animation: PropAnimation.slideUpFade(distance: 30),
            child: Text(
              collageData.title ?? 'Featured',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: colors.textColor.withValues(alpha: 0.7),
                letterSpacing: 4,
              ),
              textAlign: imageOnLeft ? TextAlign.left : TextAlign.right,
            ),
          ),
          const SizedBox(height: 20),

          // Main text (animated based on style)
          _buildAnimatedText(colors, frame),

          if (collageData.description != null) ...[
            const SizedBox(height: 30),
            AnimatedProp(
              startFrame: 100,
              duration: 30,
              animation: PropAnimation.fadeIn(),
              child: Text(
                collageData.description!,
                style: TextStyle(
                  fontSize: 20,
                  color: colors.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: imageOnLeft ? TextAlign.left : TextAlign.right,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnimatedText(TemplateTheme colors, int frame) {
    final text = collageData.subtitle ?? 'Your Top';

    switch (textAnimation) {
      case TextAnimationStyle.typewriter:
        return _buildTypewriterText(text, colors, frame);
      case TextAnimationStyle.wordByWord:
        return _buildWordByWordText(text, colors, frame);
      case TextAnimationStyle.fadeIn:
        return AnimatedProp(
          startFrame: 60,
          duration: 40,
          animation: PropAnimation.fadeIn(),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w900,
              color: colors.textColor,
              height: 1.1,
            ),
            textAlign: imageOnLeft ? TextAlign.left : TextAlign.right,
          ),
        );
    }
  }

  Widget _buildTypewriterText(String text, TemplateTheme colors, int frame) {
    final typeStart = 60;
    final charsPerFrame = 0.5;
    final visibleChars =
        ((frame - typeStart) * charsPerFrame).clamp(0, text.length).toInt();

    return Text(
      text.substring(0, visibleChars) + (visibleChars < text.length ? '_' : ''),
      style: TextStyle(
        fontSize: 56,
        fontWeight: FontWeight.w900,
        color: colors.textColor,
        height: 1.1,
      ),
      textAlign: imageOnLeft ? TextAlign.left : TextAlign.right,
    );
  }

  Widget _buildWordByWordText(String text, TemplateTheme colors, int frame) {
    final words = text.split(' ');
    final wordDelay = 15;
    final startFrame = 60;

    return Wrap(
      alignment: imageOnLeft ? WrapAlignment.start : WrapAlignment.end,
      children: words.asMap().entries.map((entry) {
        final wordStart = startFrame + entry.key * wordDelay;
        final wordProgress = ((frame - wordStart) / 20).clamp(0.0, 1.0);
        final opacity = Curves.easeOut.transform(wordProgress);
        final translateY = 20 * (1 - wordProgress);

        return Transform.translate(
          offset: Offset(0, translateY),
          child: Opacity(
            opacity: opacity,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                entry.value,
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  color: colors.textColor,
                  height: 1.3,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSplitLine(TemplateTheme colors) {
    return TimeConsumer(
      builder: (context, frame, _) {
        final lineProgress = ((frame - 40) / 30).clamp(0.0, 1.0);

        return CustomPaint(
          painter: _SplitLinePainter(
            angle: splitAngle,
            progress: lineProgress,
            color: colors.accentColor,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

/// Text animation style options.
enum TextAnimationStyle { typewriter, wordByWord, fadeIn }

class _DiagonalClipper extends CustomClipper<Path> {
  final double angle;
  final bool isLeft;

  _DiagonalClipper({required this.angle, required this.isLeft});

  @override
  Path getClip(Size size) {
    final path = Path();
    final angleRad = angle * math.pi / 180;
    final offset = size.height * math.tan(angleRad);

    if (isLeft) {
      path.moveTo(0, 0);
      path.lineTo(size.width / 2 + offset, 0);
      path.lineTo(size.width / 2 - offset, size.height);
      path.lineTo(0, size.height);
      path.close();
    } else {
      path.moveTo(size.width / 2 + offset, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width / 2 - offset, size.height);
      path.close();
    }

    return path;
  }

  @override
  bool shouldReclip(covariant _DiagonalClipper oldClipper) {
    return oldClipper.angle != angle || oldClipper.isLeft != isLeft;
  }
}

class _SplitLinePainter extends CustomPainter {
  final double angle;
  final double progress;
  final Color color;

  _SplitLinePainter({
    required this.angle,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final angleRad = angle * math.pi / 180;
    final offset = size.height * math.tan(angleRad);

    final paint = Paint()
      ..color = color.withValues(alpha: progress * 0.8)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // Draw the split line
    final start = Offset(size.width / 2 + offset, 0);
    final end = Offset(size.width / 2 - offset, size.height);

    // Animate from top to bottom
    final currentEnd = Offset(
      start.dx + (end.dx - start.dx) * progress,
      start.dy + (end.dy - start.dy) * progress,
    );

    canvas.drawLine(start, currentEnd, paint);

    // Glow effect
    final glowPaint = Paint()
      ..color = color.withValues(alpha: progress * 0.3)
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawLine(start, currentEnd, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _SplitLinePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
