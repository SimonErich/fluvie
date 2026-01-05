import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../presentation/time_consumer.dart';
import '../../declarative/animations/core/animated_prop.dart';
import '../../declarative/animations/core/prop_animation.dart';
import '../_base/template_base.dart';
import '../_base/template_config.dart';
import '../_base/template_data.dart';

/// A container that fills with liquid representing time/data.
///
/// Creates a satisfying visualization where a container (glass, jar, etc.)
/// fills up with animated liquid. The liquid level represents the main
/// metric, with bubbles and waves for visual interest.
///
/// Best used for:
/// - Total listening time
/// - Hours/minutes metrics
/// - Progress indicators
///
/// Example:
/// ```dart
/// LiquidMinutes(
///   data: DataVizData(
///     title: 'Minutes Listened',
///     metrics: [
///       MetricData(label: 'This Year', value: 45000),
///     ],
///     total: 45000,
///   ),
///   containerShape: ContainerShape.glass,
/// )
/// ```
class LiquidMinutes extends WrappedTemplate with TemplateAnimationMixin {
  /// Shape of the container.
  final ContainerShape containerShape;

  /// Color of the liquid.
  final Color? liquidColor;

  /// Whether to show bubbles.
  final bool showBubbles;

  /// Target fill percentage (0.0 - 1.0).
  final double fillTarget;

  const LiquidMinutes({
    super.key,
    required DataVizData super.data,
    super.theme,
    super.timing,
    this.containerShape = ContainerShape.glass,
    this.liquidColor,
    this.showBubbles = true,
    this.fillTarget = 0.85,
  });

  @override
  int get recommendedLength => 180;

  @override
  TemplateCategory get category => TemplateCategory.dataViz;

  @override
  String get description => 'Container fills with liquid representing data';

  @override
  TemplateTheme get defaultTheme => TemplateTheme.ocean;

  DataVizData get dataVizData => data as DataVizData;

  @override
  Widget build(BuildContext context) {
    final colors = effectiveTheme;

    return Container(
      color: colors.backgroundColor,
      child: Stack(
        children: [
          // Title
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: AnimatedProp(
              startFrame: 0,
              duration: 30,
              animation: PropAnimation.slideUpFade(distance: 20),
              child: Text(
                dataVizData.title ?? 'Your Stats',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: colors.textColor,
                ),
              ),
            ),
          ),

          // Liquid container
          Positioned.fill(child: Center(child: _buildLiquidContainer(colors))),

          // Floating text on top of liquid
          Positioned.fill(child: Center(child: _buildFloatingStats(colors))),
        ],
      ),
    );
  }

  Widget _buildLiquidContainer(TemplateTheme colors) {
    return TimeConsumer(
      builder: (context, frame, _) {
        final time = frame / 30.0;

        // Fill animation
        const fillStart = 30;
        const fillDuration = 100;
        final fillProgress = ((frame - fillStart) / fillDuration).clamp(
          0.0,
          1.0,
        );
        final easedFill =
            Curves.easeOutCubic.transform(fillProgress) * fillTarget;

        return SizedBox(
          width: 300,
          height: 450,
          child: CustomPaint(
            painter: _LiquidContainerPainter(
              shape: containerShape,
              fillLevel: easedFill,
              liquidColor: liquidColor ?? colors.primaryColor,
              containerColor: colors.secondaryColor,
              time: time,
              showBubbles: showBubbles,
            ),
            size: Size.infinite,
          ),
        );
      },
    );
  }

  Widget _buildFloatingStats(TemplateTheme colors) {
    final mainMetric =
        dataVizData.metrics.isNotEmpty ? dataVizData.metrics.first : null;

    final displayValue = _formatMinutes(dataVizData.total.toDouble());

    return TimeConsumer(
      builder: (context, frame, _) {
        return AnimatedProp(
          startFrame: 80,
          duration: 40,
          animation: PropAnimation.combine([
            const PropAnimation.scale(start: 0.8, end: 1.0),
            PropAnimation.fadeIn(),
          ]),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main number
              Text(
                displayValue,
                style: TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w900,
                  color: colors.textColor,
                  shadows: [
                    Shadow(
                      color: colors.backgroundColor.withValues(alpha: 0.8),
                      blurRadius: 20,
                    ),
                  ],
                ),
              ),
              Text(
                mainMetric?.label ?? 'minutes',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: colors.textColor.withValues(alpha: 0.8),
                ),
              ),
              if (dataVizData.subtitle != null) ...[
                const SizedBox(height: 20),
                Text(
                  dataVizData.subtitle!,
                  style: TextStyle(
                    fontSize: 18,
                    color: colors.textColor.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatMinutes(double minutes) {
    if (minutes >= 60) {
      final hours = (minutes / 60).floor();
      final remainingMinutes = (minutes % 60).floor();
      if (hours >= 100) {
        return '${hours}h';
      }
      return '${hours}h ${remainingMinutes}m';
    }
    return '${minutes.toInt()}m';
  }
}

/// Shape options for the liquid container.
enum ContainerShape { glass, jar, bottle, beaker }

class _LiquidContainerPainter extends CustomPainter {
  final ContainerShape shape;
  final double fillLevel;
  final Color liquidColor;
  final Color containerColor;
  final double time;
  final bool showBubbles;

  _LiquidContainerPainter({
    required this.shape,
    required this.fillLevel,
    required this.liquidColor,
    required this.containerColor,
    required this.time,
    required this.showBubbles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final containerPath = _getContainerPath(size);
    final liquidPath = _getLiquidPath(size);

    // Container outline
    final containerPaint = Paint()
      ..color = containerColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Container glass effect
    final glassPaint = Paint()
      ..color = containerColor.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    // Draw container glass
    canvas.drawPath(containerPath, glassPaint);

    // Clip to container for liquid
    canvas.save();
    canvas.clipPath(containerPath);

    // Draw liquid
    if (fillLevel > 0) {
      final liquidPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            liquidColor.withValues(alpha: 0.7),
            liquidColor,
            liquidColor.withValues(alpha: 0.9),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

      canvas.drawPath(liquidPath, liquidPaint);

      // Draw wave on top
      _drawWave(canvas, size);

      // Draw bubbles
      if (showBubbles) {
        _drawBubbles(canvas, size);
      }
    }

    canvas.restore();

    // Draw container outline
    canvas.drawPath(containerPath, containerPaint);

    // Glass shine effect
    _drawGlassShine(canvas, size);
  }

  Path _getContainerPath(Size size) {
    final path = Path();
    final width = size.width;
    final height = size.height;

    switch (shape) {
      case ContainerShape.glass:
        // Wine glass shape
        path.moveTo(width * 0.2, height * 0.9);
        path.lineTo(width * 0.3, height * 0.15);
        path.quadraticBezierTo(
          width * 0.5,
          height * 0.05,
          width * 0.7,
          height * 0.15,
        );
        path.lineTo(width * 0.8, height * 0.9);
        path.quadraticBezierTo(
          width * 0.5,
          height * 0.95,
          width * 0.2,
          height * 0.9,
        );
        break;

      case ContainerShape.jar:
        // Mason jar shape
        path.moveTo(width * 0.15, height * 0.9);
        path.lineTo(width * 0.15, height * 0.15);
        path.lineTo(width * 0.25, height * 0.1);
        path.lineTo(width * 0.75, height * 0.1);
        path.lineTo(width * 0.85, height * 0.15);
        path.lineTo(width * 0.85, height * 0.9);
        path.close();
        break;

      case ContainerShape.bottle:
        // Bottle shape
        path.moveTo(width * 0.25, height * 0.9);
        path.lineTo(width * 0.25, height * 0.4);
        path.lineTo(width * 0.4, height * 0.2);
        path.lineTo(width * 0.4, height * 0.1);
        path.lineTo(width * 0.6, height * 0.1);
        path.lineTo(width * 0.6, height * 0.2);
        path.lineTo(width * 0.75, height * 0.4);
        path.lineTo(width * 0.75, height * 0.9);
        path.close();
        break;

      case ContainerShape.beaker:
        // Lab beaker shape
        path.moveTo(width * 0.15, height * 0.9);
        path.lineTo(width * 0.2, height * 0.1);
        path.lineTo(width * 0.3, height * 0.1);
        path.lineTo(width * 0.3, height * 0.05);
        path.lineTo(width * 0.7, height * 0.05);
        path.lineTo(width * 0.7, height * 0.1);
        path.lineTo(width * 0.8, height * 0.1);
        path.lineTo(width * 0.85, height * 0.9);
        path.close();
        break;
    }

    return path;
  }

  Path _getLiquidPath(Size size) {
    final path = Path();
    final liquidTop = size.height * (1 - fillLevel);

    // Wave effect at top of liquid
    const waveHeight = 8.0;
    const waveFreq = 3.0;

    path.moveTo(0, size.height);
    path.lineTo(0, liquidTop);

    // Wave curve
    for (var x = 0.0; x <= size.width; x += 5) {
      final y = liquidTop +
          math.sin((x / size.width * waveFreq + time) * math.pi * 2) *
              waveHeight;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();

    return path;
  }

  void _drawWave(Canvas canvas, Size size) {
    final liquidTop = size.height * (1 - fillLevel);
    final wavePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final wavePath = Path();
    const waveHeight = 5.0;

    wavePath.moveTo(0, liquidTop);
    for (var x = 0.0; x <= size.width; x += 5) {
      final y = liquidTop +
          math.sin((x / size.width * 4 + time * 1.5) * math.pi * 2) *
              waveHeight;
      wavePath.lineTo(x, y);
    }

    canvas.drawPath(wavePath, wavePaint);
  }

  void _drawBubbles(Canvas canvas, Size size) {
    final random = math.Random(42);
    const bubbleCount = 10;
    final liquidTop = size.height * (1 - fillLevel);

    final bubblePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;

    for (var i = 0; i < bubbleCount; i++) {
      final baseX = size.width * 0.2 + random.nextDouble() * size.width * 0.6;
      final bubbleSize = 3.0 + random.nextDouble() * 8;

      // Animate bubble position
      final animOffset = (time * 50 + i * 30) % (size.height - liquidTop);
      final y = size.height - animOffset;

      if (y > liquidTop && y < size.height) {
        // Wobble
        final x = baseX + math.sin(time * 3 + i) * 5;
        canvas.drawCircle(Offset(x, y), bubbleSize, bubblePaint);
      }
    }
  }

  void _drawGlassShine(Canvas canvas, Size size) {
    final shinePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.3),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromLTWH(size.width * 0.2, 0, size.width * 0.15, size.height),
      );

    final shinePath = Path()
      ..moveTo(size.width * 0.25, size.height * 0.15)
      ..lineTo(size.width * 0.3, size.height * 0.85)
      ..lineTo(size.width * 0.35, size.height * 0.85)
      ..lineTo(size.width * 0.32, size.height * 0.15)
      ..close();

    canvas.drawPath(shinePath, shinePaint);
  }

  @override
  bool shouldRepaint(covariant _LiquidContainerPainter oldDelegate) {
    return oldDelegate.fillLevel != fillLevel || oldDelegate.time != time;
  }
}
