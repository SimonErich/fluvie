import 'dart:math' as math;
import 'package:flutter/widgets.dart';

import '../../presentation/time_consumer.dart';

/// Type of chart to render.
enum ChartType {
  /// Vertical bar chart.
  bar,

  /// Line chart.
  line,

  /// Pie/donut chart.
  pie,

  /// Horizontal bar chart.
  horizontalBar,
}

/// Data point for charts.
class ChartData {
  /// Label for this data point.
  final String label;

  /// Numeric value.
  final double value;

  /// Optional color override.
  final Color? color;

  const ChartData({required this.label, required this.value, this.color});
}

/// A widget that renders animated charts.
///
/// [AnimatedChart] displays data as bar, line, or pie charts with
/// animated value transitions.
///
/// Example:
/// ```dart
/// AnimatedChart.bar(
///   data: [
///     ChartData(label: 'Jan', value: 100),
///     ChartData(label: 'Feb', value: 150),
///     ChartData(label: 'Mar', value: 120),
///   ],
///   animationDuration: 60,
///   startFrame: 30,
/// )
/// ```
class AnimatedChart extends StatelessWidget {
  /// Data points to display.
  final List<ChartData> data;

  /// Type of chart.
  final ChartType type;

  /// Duration of the value animation in frames.
  final int animationDuration;

  /// Frame at which animation starts.
  final int startFrame;

  /// Easing curve for the animation.
  final Curve curve;

  /// Style for axis labels.
  final TextStyle? labelStyle;

  /// Style for value labels.
  final TextStyle? valueStyle;

  /// Color of the chart axis.
  final Color? axisColor;

  /// Default colors for data points.
  final List<Color> colors;

  /// Whether to show value labels.
  final bool showValues;

  /// Whether to show axis labels.
  final bool showLabels;

  /// Bar width (for bar charts).
  final double barWidth;

  /// Line width (for line charts).
  final double lineWidth;

  /// Dot radius (for line charts).
  final double dotRadius;

  /// Inner radius ratio for pie charts (0 = pie, >0 = donut).
  final double innerRadiusRatio;

  /// Creates an animated chart.
  const AnimatedChart({
    super.key,
    required this.data,
    required this.type,
    this.animationDuration = 60,
    this.startFrame = 0,
    this.curve = Curves.easeOut,
    this.labelStyle,
    this.valueStyle,
    this.axisColor,
    this.colors = const [
      Color(0xFF4285F4),
      Color(0xFFEA4335),
      Color(0xFFFBBC05),
      Color(0xFF34A853),
      Color(0xFF9C27B0),
      Color(0xFFFF9800),
    ],
    this.showValues = true,
    this.showLabels = true,
    this.barWidth = 40,
    this.lineWidth = 2,
    this.dotRadius = 4,
    this.innerRadiusRatio = 0,
  });

  /// Creates a bar chart.
  const AnimatedChart.bar({
    super.key,
    required this.data,
    this.animationDuration = 60,
    this.startFrame = 0,
    this.curve = Curves.easeOut,
    this.labelStyle,
    this.valueStyle,
    this.axisColor,
    this.colors = const [
      Color(0xFF4285F4),
      Color(0xFFEA4335),
      Color(0xFFFBBC05),
      Color(0xFF34A853),
    ],
    this.showValues = true,
    this.showLabels = true,
    this.barWidth = 40,
  })  : type = ChartType.bar,
        lineWidth = 2,
        dotRadius = 4,
        innerRadiusRatio = 0;

  /// Creates a line chart.
  AnimatedChart.line({
    super.key,
    required this.data,
    this.animationDuration = 60,
    this.startFrame = 0,
    this.curve = Curves.easeOut,
    this.labelStyle,
    this.valueStyle,
    this.axisColor,
    Color color = const Color(0xFF4285F4),
    this.showValues = false,
    this.showLabels = true,
    this.lineWidth = 2,
    this.dotRadius = 4,
  })  : type = ChartType.line,
        colors = [color],
        barWidth = 40,
        innerRadiusRatio = 0;

  /// Creates a pie chart.
  const AnimatedChart.pie({
    super.key,
    required this.data,
    this.animationDuration = 60,
    this.startFrame = 0,
    this.curve = Curves.easeOut,
    this.labelStyle,
    this.valueStyle,
    this.colors = const [
      Color(0xFF4285F4),
      Color(0xFFEA4335),
      Color(0xFFFBBC05),
      Color(0xFF34A853),
      Color(0xFF9C27B0),
      Color(0xFFFF9800),
    ],
    this.showValues = true,
    this.showLabels = true,
    double donutRatio = 0,
  })  : type = ChartType.pie,
        axisColor = null,
        barWidth = 40,
        lineWidth = 2,
        dotRadius = 4,
        innerRadiusRatio = donutRatio;

  /// Creates a donut chart.
  const AnimatedChart.donut({
    super.key,
    required this.data,
    this.animationDuration = 60,
    this.startFrame = 0,
    this.curve = Curves.easeOut,
    this.labelStyle,
    this.valueStyle,
    this.colors = const [
      Color(0xFF4285F4),
      Color(0xFFEA4335),
      Color(0xFFFBBC05),
      Color(0xFF34A853),
      Color(0xFF9C27B0),
      Color(0xFFFF9800),
    ],
    this.showValues = true,
    this.showLabels = true,
    double innerRatio = 0.6,
  })  : type = ChartType.pie,
        axisColor = null,
        barWidth = 40,
        lineWidth = 2,
        dotRadius = 4,
        innerRadiusRatio = innerRatio;

  @override
  Widget build(BuildContext context) {
    return TimeConsumer(
      builder: (context, frame, _) {
        final relativeFrame = frame - startFrame;
        final progress = _calculateProgress(relativeFrame);

        return CustomPaint(
          size: Size.infinite,
          painter: _ChartPainter(
            data: data,
            type: type,
            progress: progress,
            colors: colors,
            axisColor: axisColor ?? const Color(0xFF666666),
            barWidth: barWidth,
            lineWidth: lineWidth,
            dotRadius: dotRadius,
            innerRadiusRatio: innerRadiusRatio,
            showValues: showValues,
            showLabels: showLabels,
            labelStyle: labelStyle,
            valueStyle: valueStyle,
          ),
        );
      },
    );
  }

  double _calculateProgress(int relativeFrame) {
    if (relativeFrame < 0) return 0.0;
    if (relativeFrame >= animationDuration) return 1.0;
    final linear = relativeFrame / animationDuration;
    return curve.transform(linear);
  }
}

class _ChartPainter extends CustomPainter {
  final List<ChartData> data;
  final ChartType type;
  final double progress;
  final List<Color> colors;
  final Color axisColor;
  final double barWidth;
  final double lineWidth;
  final double dotRadius;
  final double innerRadiusRatio;
  final bool showValues;
  final bool showLabels;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  _ChartPainter({
    required this.data,
    required this.type,
    required this.progress,
    required this.colors,
    required this.axisColor,
    required this.barWidth,
    required this.lineWidth,
    required this.dotRadius,
    required this.innerRadiusRatio,
    required this.showValues,
    required this.showLabels,
    this.labelStyle,
    this.valueStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    switch (type) {
      case ChartType.bar:
        _paintBarChart(canvas, size);
        break;
      case ChartType.horizontalBar:
        _paintHorizontalBarChart(canvas, size);
        break;
      case ChartType.line:
        _paintLineChart(canvas, size);
        break;
      case ChartType.pie:
        _paintPieChart(canvas, size);
        break;
    }
  }

  void _paintBarChart(Canvas canvas, Size size) {
    final maxValue = data.map((d) => d.value).reduce(math.max);
    final chartHeight = size.height - 40; // Leave space for labels
    final chartWidth = size.width;
    final spacing = (chartWidth - (data.length * barWidth)) / (data.length + 1);

    // Draw bars
    for (int i = 0; i < data.length; i++) {
      final d = data[i];
      final color = d.color ?? colors[i % colors.length];
      final animatedValue = d.value * progress;
      final barHeight = (animatedValue / maxValue) * chartHeight;

      final x = spacing + i * (barWidth + spacing);
      final y = chartHeight - barHeight;

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(4),
        ),
        paint,
      );

      // Draw label
      if (showLabels) {
        _drawText(
          canvas,
          d.label,
          Offset(x + barWidth / 2, chartHeight + 10),
          labelStyle ?? const TextStyle(fontSize: 12, color: Color(0xFFFFFFFF)),
        );
      }

      // Draw value
      if (showValues && progress > 0.5) {
        _drawText(
          canvas,
          animatedValue.toInt().toString(),
          Offset(x + barWidth / 2, y - 15),
          valueStyle ?? const TextStyle(fontSize: 12, color: Color(0xFFFFFFFF)),
        );
      }
    }
  }

  void _paintHorizontalBarChart(Canvas canvas, Size size) {
    final maxValue = data.map((d) => d.value).reduce(math.max);
    final chartWidth = size.width - 80; // Leave space for labels
    final barHeight = math.min(30.0, (size.height - 20) / data.length - 10);
    final spacing =
        (size.height - (data.length * barHeight)) / (data.length + 1);

    for (int i = 0; i < data.length; i++) {
      final d = data[i];
      final color = d.color ?? colors[i % colors.length];
      final animatedValue = d.value * progress;
      final barWidth = (animatedValue / maxValue) * chartWidth;

      final x = 60.0;
      final y = spacing + i * (barHeight + spacing);

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(4),
        ),
        paint,
      );

      // Draw label
      if (showLabels) {
        _drawText(
          canvas,
          d.label,
          Offset(30, y + barHeight / 2),
          labelStyle ?? const TextStyle(fontSize: 12, color: Color(0xFFFFFFFF)),
          textAlign: TextAlign.right,
        );
      }
    }
  }

  void _paintLineChart(Canvas canvas, Size size) {
    final maxValue = data.map((d) => d.value).reduce(math.max);
    final chartHeight = size.height - 40;
    final chartWidth = size.width - 20;
    final pointSpacing = chartWidth / (data.length - 1);

    final color = colors.first;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final points = <Offset>[];

    for (int i = 0; i < data.length; i++) {
      final d = data[i];
      final animatedValue = d.value * progress;
      final x = 10 + i * pointSpacing;
      final y = chartHeight - (animatedValue / maxValue) * chartHeight;
      points.add(Offset(x, y));

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }

      // Draw label
      if (showLabels) {
        _drawText(
          canvas,
          d.label,
          Offset(x, chartHeight + 10),
          labelStyle ?? const TextStyle(fontSize: 12, color: Color(0xFFFFFFFF)),
        );
      }
    }

    // Draw line with progress
    final pathMetrics = path.computeMetrics().first;
    final extractPath = pathMetrics.extractPath(
      0,
      pathMetrics.length * progress,
    );
    canvas.drawPath(extractPath, linePaint);

    // Draw dots
    final visiblePoints = (points.length * progress).ceil();
    for (int i = 0; i < visiblePoints; i++) {
      canvas.drawCircle(points[i], dotRadius, dotPaint);
    }
  }

  void _paintPieChart(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 20;
    final innerRadius = radius * innerRadiusRatio;

    final total = data.map((d) => d.value).reduce((a, b) => a + b);
    var startAngle = -math.pi / 2;

    for (int i = 0; i < data.length; i++) {
      final d = data[i];
      final color = d.color ?? colors[i % colors.length];
      final sweepAngle = (d.value / total) * 2 * math.pi * progress;

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      if (innerRadiusRatio > 0) {
        // Draw donut segment
        final path = Path()
          ..moveTo(
            center.dx + innerRadius * math.cos(startAngle),
            center.dy + innerRadius * math.sin(startAngle),
          )
          ..lineTo(
            center.dx + radius * math.cos(startAngle),
            center.dy + radius * math.sin(startAngle),
          )
          ..arcTo(
            Rect.fromCircle(center: center, radius: radius),
            startAngle,
            sweepAngle,
            false,
          )
          ..lineTo(
            center.dx + innerRadius * math.cos(startAngle + sweepAngle),
            center.dy + innerRadius * math.sin(startAngle + sweepAngle),
          )
          ..arcTo(
            Rect.fromCircle(center: center, radius: innerRadius),
            startAngle + sweepAngle,
            -sweepAngle,
            false,
          )
          ..close();
        canvas.drawPath(path, paint);
      } else {
        // Draw pie segment
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          true,
          paint,
        );
      }

      startAngle += sweepAngle;
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset position,
    TextStyle style, {
    TextAlign textAlign = TextAlign.center,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: textAlign,
    );
    textPainter.layout();

    final offset = Offset(
      position.dx - textPainter.width / 2,
      position.dy - textPainter.height / 2,
    );
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
