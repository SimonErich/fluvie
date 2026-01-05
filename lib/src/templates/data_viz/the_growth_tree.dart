import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../presentation/time_consumer.dart';
import '../../declarative/animations/core/animated_prop.dart';
import '../../declarative/animations/core/prop_animation.dart';
import '../_base/template_base.dart';
import '../_base/template_config.dart';
import '../_base/template_data.dart';

/// A vine-like line chart with data points blooming as flowers.
///
/// Creates an organic growth visualization where a vine grows from left
/// to right, with data points represented as blooming flowers or leaves
/// along the path. Perfect for showing progress or growth over time.
///
/// Best used for:
/// - Progress over time
/// - Listening hours per month
/// - Growth metrics
///
/// Example:
/// ```dart
/// TheGrowthTree(
///   data: DataVizData(
///     title: 'Your Year in Music',
///     metrics: [
///       MetricData(label: 'Jan', value: 20),
///       MetricData(label: 'Feb', value: 35),
///       MetricData(label: 'Mar', value: 45),
///       // ...
///     ],
///   ),
/// )
/// ```
class TheGrowthTree extends WrappedTemplate with TemplateAnimationMixin {
  /// Maximum height of the vine peaks.
  final double maxVineHeight;

  /// Color of the vine.
  final Color? vineColor;

  /// Whether flowers bloom at data points.
  final bool showFlowers;

  /// Seed for deterministic random variations.
  final int seed;

  const TheGrowthTree({
    super.key,
    required DataVizData super.data,
    super.theme,
    super.timing,
    this.maxVineHeight = 300,
    this.vineColor,
    this.showFlowers = true,
    this.seed = 42,
  });

  @override
  int get recommendedLength => 200;

  @override
  TemplateCategory get category => TemplateCategory.dataViz;

  @override
  String get description => 'Vine-like line chart with blooming data points';

  @override
  TemplateTheme get defaultTheme => TemplateTheme.pastel;

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
                dataVizData.title ?? 'Your Growth',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w700,
                  color: colors.textColor,
                ),
              ),
            ),
          ),

          // Growth vine
          Positioned.fill(child: _buildGrowthVine(colors)),

          // Summary
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: AnimatedProp(
              startFrame: 160,
              duration: 30,
              animation: PropAnimation.slideUpFade(distance: 20),
              child: Text(
                dataVizData.subtitle ??
                    'Total: ${dataVizData.total.toStringAsFixed(0)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: colors.textColor.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthVine(TemplateTheme colors) {
    return TimeConsumer(
      builder: (context, frame, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final metrics = dataVizData.metrics;
            if (metrics.isEmpty) return const SizedBox.shrink();

            final height = constraints.maxHeight;
            final centerY = height * 0.55;

            // Calculate vine growth progress
            const growthStart = 40;
            const growthDuration = 100;
            final growthProgress =
                ((frame - growthStart) / growthDuration).clamp(0.0, 1.0);
            final easedGrowth = Curves.easeInOutCubic.transform(growthProgress);

            return CustomPaint(
              painter: _GrowthVinePainter(
                metrics: metrics,
                maxValue: dataVizData.effectiveMaxValue,
                growthProgress: easedGrowth,
                centerY: centerY,
                maxHeight: maxVineHeight,
                vineColor: vineColor ?? colors.primaryColor,
                flowerColor: colors.accentColor,
                leafColor: colors.secondaryColor,
                textColor: colors.textColor,
                showFlowers: showFlowers,
                seed: seed,
                frame: frame,
              ),
              size: Size.infinite,
            );
          },
        );
      },
    );
  }
}

class _GrowthVinePainter extends CustomPainter {
  final List<MetricData> metrics;
  final double maxValue;
  final double growthProgress;
  final double centerY;
  final double maxHeight;
  final Color vineColor;
  final Color flowerColor;
  final Color leafColor;
  final Color textColor;
  final bool showFlowers;
  final int seed;
  final int frame;

  _GrowthVinePainter({
    required this.metrics,
    required this.maxValue,
    required this.growthProgress,
    required this.centerY,
    required this.maxHeight,
    required this.vineColor,
    required this.flowerColor,
    required this.leafColor,
    required this.textColor,
    required this.showFlowers,
    required this.seed,
    required this.frame,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (metrics.isEmpty) return;

    final random = math.Random(seed);
    const padding = 80.0;
    final usableWidth = size.width - padding * 2;
    final segmentWidth =
        usableWidth / (metrics.length - 1).clamp(1, metrics.length);

    // Calculate points
    final points = <Offset>[];
    for (var i = 0; i < metrics.length; i++) {
      final x = padding + (i * segmentWidth);
      final normalizedValue = metrics[i].value / maxValue;
      final y = centerY - (normalizedValue * maxHeight);
      points.add(Offset(x, y));
    }

    // Draw vine up to growth progress
    final currentPointIndex = (growthProgress * (points.length - 1)).floor();
    final pointProgress =
        (growthProgress * (points.length - 1)) - currentPointIndex;

    // Vine path
    final vinePaint = Paint()
      ..color = vineColor
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    for (var i = 1; i <= currentPointIndex && i < points.length; i++) {
      _drawVineSegment(
        canvas,
        path,
        points[i - 1],
        points[i],
        vinePaint,
        random,
      );
    }

    // Partial segment to current growth point
    if (currentPointIndex < points.length - 1) {
      final start = points[currentPointIndex];
      final end = points[currentPointIndex + 1];
      final current = Offset(
        start.dx + (end.dx - start.dx) * pointProgress,
        start.dy + (end.dy - start.dy) * pointProgress,
      );
      _drawVineSegment(canvas, path, start, current, vinePaint, random);
    }

    canvas.drawPath(path, vinePaint);

    // Draw data point flowers and labels
    for (var i = 0; i <= currentPointIndex && i < points.length; i++) {
      final point = points[i];
      final metric = metrics[i];

      // Bloom animation
      final bloomDelay = i * 0.05;
      final bloomProgress = ((growthProgress - bloomDelay) / 0.15).clamp(
        0.0,
        1.0,
      );

      if (bloomProgress > 0) {
        // Draw leaf
        _drawLeaf(canvas, point, random, bloomProgress);

        // Draw flower at data point
        if (showFlowers) {
          _drawFlower(canvas, point, metric, bloomProgress, i);
        }

        // Draw label
        if (bloomProgress > 0.5) {
          _drawLabel(canvas, point, metric, bloomProgress, size);
        }
      }
    }
  }

  void _drawVineSegment(
    Canvas canvas,
    Path path,
    Offset start,
    Offset end,
    Paint paint,
    math.Random random,
  ) {
    // Add organic waviness to the vine
    final midX = (start.dx + end.dx) / 2;
    final midY = (start.dy + end.dy) / 2 + (random.nextDouble() - 0.5) * 20;

    path.quadraticBezierTo(midX, midY, end.dx, end.dy);
  }

  void _drawLeaf(
    Canvas canvas,
    Offset point,
    math.Random random,
    double progress,
  ) {
    final leafPaint = Paint()
      ..color = leafColor.withValues(alpha: 0.7 * progress)
      ..style = PaintingStyle.fill;

    final leafSize = 20.0 * progress;
    final leafAngle = random.nextDouble() * math.pi / 4;
    final side = random.nextBool() ? 1 : -1;

    canvas.save();
    canvas.translate(point.dx, point.dy);
    canvas.rotate(leafAngle * side);

    final leafPath = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(
        leafSize * 0.5 * side,
        -leafSize * 0.3,
        leafSize * side,
        0,
      )
      ..quadraticBezierTo(leafSize * 0.5 * side, leafSize * 0.3, 0, 0);

    canvas.drawPath(leafPath, leafPaint);
    canvas.restore();
  }

  void _drawFlower(
    Canvas canvas,
    Offset point,
    MetricData metric,
    double progress,
    int index,
  ) {
    final flowerSize = 25.0 * Curves.easeOutBack.transform(progress);
    final petalCount = 5 + (index % 3);
    final color = metric.color ?? flowerColor;

    // Petals
    final petalPaint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    for (var i = 0; i < petalCount; i++) {
      final angle = (i / petalCount) * 2 * math.pi;
      final petalPath = Path();

      canvas.save();
      canvas.translate(point.dx, point.dy);
      canvas.rotate(angle);

      petalPath
        ..moveTo(0, 0)
        ..quadraticBezierTo(
          flowerSize * 0.4,
          -flowerSize * 0.3,
          flowerSize * 0.8,
          0,
        )
        ..quadraticBezierTo(flowerSize * 0.4, flowerSize * 0.3, 0, 0);

      canvas.drawPath(petalPath, petalPaint);
      canvas.restore();
    }

    // Center
    canvas.drawCircle(
      point,
      flowerSize * 0.3,
      Paint()..color = Colors.white.withValues(alpha: progress),
    );
  }

  void _drawLabel(
    Canvas canvas,
    Offset point,
    MetricData metric,
    double progress,
    Size size,
  ) {
    final textSpan = TextSpan(
      text: metric.label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textColor.withValues(alpha: progress * 0.8),
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final valueSpan = TextSpan(
      text: metric.value is double
          ? metric.value.toStringAsFixed(0)
          : '${metric.value}',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: textColor.withValues(alpha: progress),
      ),
    );

    final valuePainter = TextPainter(
      text: valueSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    // Position below the flower
    final labelY = point.dy + 45;

    textPainter.paint(canvas, Offset(point.dx - textPainter.width / 2, labelY));

    valuePainter.paint(
      canvas,
      Offset(point.dx - valuePainter.width / 2, labelY + 18),
    );
  }

  @override
  bool shouldRepaint(covariant _GrowthVinePainter oldDelegate) {
    return oldDelegate.growthProgress != growthProgress ||
        oldDelegate.frame != frame;
  }
}
