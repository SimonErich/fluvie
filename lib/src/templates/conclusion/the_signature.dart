import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../presentation/time_consumer.dart';
import '../../declarative/animations/core/animated_prop.dart';
import '../../declarative/animations/core/prop_animation.dart';
import '../_base/template_base.dart';
import '../_base/template_config.dart';
import '../_base/template_data.dart';

/// Name handwritten via animated path drawing.
///
/// Creates an elegant conclusion where the user's name or title
/// appears to be written by hand, with an animated pen stroke
/// effect. Perfect for personal endings.
///
/// Best used for:
/// - Personal sign-offs
/// - Name reveals
/// - Artistic endings
///
/// Example:
/// ```dart
/// TheSignature(
///   data: SummaryData(
///     title: 'Thank You',
///     name: 'John Doe',
///     subtitle: 'See you next year!',
///   ),
/// )
/// ```
class TheSignature extends WrappedTemplate with TemplateAnimationMixin {
  /// Stroke width for the signature.
  final double strokeWidth;

  /// Whether to show the "pen" drawing.
  final bool showPen;

  /// Color of the signature.
  final Color? signatureColor;

  const TheSignature({
    super.key,
    required SummaryData super.data,
    super.theme,
    super.timing,
    this.strokeWidth = 4.0,
    this.showPen = true,
    this.signatureColor,
  });

  @override
  int get recommendedLength => 200;

  @override
  TemplateCategory get category => TemplateCategory.conclusion;

  @override
  String get description => 'Name handwritten via animated path';

  @override
  TemplateTheme get defaultTheme => TemplateTheme.minimal;

  SummaryData get summaryData => data as SummaryData;

  @override
  Widget build(BuildContext context) {
    final colors = effectiveTheme;

    return Container(
      color: colors.backgroundColor,
      child: Stack(
        children: [
          // Thank you message
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: _buildThankYou(colors),
          ),

          // Signature animation
          Positioned.fill(child: Center(child: _buildSignature(colors))),

          // Subtitle/ending
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: _buildEnding(colors),
          ),
        ],
      ),
    );
  }

  Widget _buildThankYou(TemplateTheme colors) {
    return AnimatedProp(
      startFrame: 20,
      duration: 35,
      animation: PropAnimation.slideUpFade(distance: 20),
      child: Text(
        summaryData.title ?? 'Thank You',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w300,
          color: colors.textColor.withValues(alpha: 0.7),
          letterSpacing: 8,
        ),
      ),
    );
  }

  Widget _buildSignature(TemplateTheme colors) {
    final name = summaryData.name ?? 'Your Name';
    final color = signatureColor ?? colors.primaryColor;

    return TimeConsumer(
      builder: (context, frame, _) {
        // Signature animation progress
        const signatureStart = 60;
        const signatureDuration = 80;
        final progress = ((frame - signatureStart) / signatureDuration).clamp(
          0.0,
          1.0,
        );

        return SizedBox(
          width: 500,
          height: 200,
          child: Stack(
            children: [
              // Signature path
              CustomPaint(
                painter: _SignaturePainter(
                  text: name,
                  progress: progress,
                  color: color,
                  strokeWidth: strokeWidth,
                ),
                size: Size.infinite,
              ),

              // Pen/cursor
              if (showPen && progress > 0 && progress < 1)
                Positioned(
                  left: _getPenPosition(name, progress, 500).dx - 10,
                  top: _getPenPosition(name, progress, 200).dy - 20,
                  child: Transform.rotate(
                    angle: -0.5,
                    child: Icon(
                      Icons.edit,
                      size: 24,
                      color: colors.accentColor,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Offset _getPenPosition(String text, double progress, double width) {
    // Approximate position along the signature path
    final x = progress * width * 0.9 + 25;
    final y = 100 + math.sin(progress * math.pi * 3) * 30;
    return Offset(x, y);
  }

  Widget _buildEnding(TemplateTheme colors) {
    return Column(
      children: [
        if (summaryData.subtitle != null)
          AnimatedProp(
            startFrame: 160,
            duration: 30,
            animation: PropAnimation.fadeIn(),
            child: Text(
              summaryData.subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                color: colors.textColor.withValues(alpha: 0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        const SizedBox(height: 20),
        AnimatedProp(
          startFrame: 180,
          duration: 20,
          animation: PropAnimation.slideUpFade(distance: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: colors.primaryColor,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              summaryData.year?.toString() ?? DateTime.now().year.toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.backgroundColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final String text;
  final double progress;
  final Color color;
  final double strokeWidth;

  _SignaturePainter({
    required this.text,
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Generate signature path based on text
    final path = _generateSignaturePath(text, size);

    // Measure path length
    final pathMetrics = path.computeMetrics();
    final totalLength = pathMetrics.fold<double>(
      0,
      (sum, metric) => sum + metric.length,
    );

    // Draw partial path based on progress
    final currentLength = totalLength * progress;
    var drawnLength = 0.0;

    for (final metric in pathMetrics) {
      if (drawnLength >= currentLength) break;

      final remainingLength = currentLength - drawnLength;
      final segmentLength = math.min(remainingLength, metric.length);

      final extractedPath = metric.extractPath(0, segmentLength);
      canvas.drawPath(extractedPath, paint);

      drawnLength += metric.length;
    }
  }

  Path _generateSignaturePath(String text, Size size) {
    final path = Path();
    final centerY = size.height / 2;
    const startX = 25.0;
    final charWidth = (size.width - 50) / text.length;

    path.moveTo(startX, centerY);

    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      final x = startX + i * charWidth;

      // Generate stylized letter paths
      _addCharacterPath(path, char, x, centerY, charWidth);
    }

    // Add flourish at end
    final endX = startX + text.length * charWidth;
    path.quadraticBezierTo(endX + 30, centerY - 40, endX + 60, centerY + 10);

    return path;
  }

  void _addCharacterPath(
    Path path,
    String char,
    double x,
    double centerY,
    double width,
  ) {
    // Simplified cursive-style character paths
    const amplitude = 30.0;
    final isVowel = 'aeiouAEIOU'.contains(char);
    final isUpper = char.toUpperCase() == char && char.toLowerCase() != char;

    // Vary height based on character
    final heightVariation = isUpper ? -20.0 : (isVowel ? 10.0 : 0.0);

    // Create flowing curves
    path.quadraticBezierTo(
      x + width * 0.25,
      centerY + heightVariation - amplitude,
      x + width * 0.5,
      centerY + heightVariation,
    );

    path.quadraticBezierTo(
      x + width * 0.75,
      centerY + heightVariation + amplitude * 0.5,
      x + width,
      centerY,
    );
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
