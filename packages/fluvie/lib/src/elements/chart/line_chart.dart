import 'dart:ui' show Canvas, Color, Paint, PaintingStyle, Path, Rect, Size, StrokeCap, StrokeJoin;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/chart/data/chart_series.dart';
import 'package:fluvie/src/elements/chart/painter/axis_painter.dart';
import 'package:fluvie/src/elements/chart/painter/chart_painter.dart';
import 'package:fluvie/src/elements/chart/render/line_geometry.dart';
import 'package:fluvie/src/elements/chart/scale/chart_scale.dart';
import 'package:fluvie/src/elements/reveal/reveal_progress.dart';
import 'package:fluvie/src/theme/fluvie_tokens.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

/// The stroke width every line / area outline draws at.
const double _lineStroke = 2.5;

/// Builds the [LineChartPainter] for `Chart.line` at [frame] within [scope] —
/// the data-transform layer that resolves each series and the shared reveal
/// progress, leaving pixel placement to the painter.
LineChartPainter buildLinePainter({
  required int frame,
  required TimeScopeData scope,
  required List<ChartSeries> series,
  required Time reveal,
  FluvieTokens tokens = const FluvieTokens.fallback(),
}) => LineChartPainter(
  tokens: tokens,
  progress: revealProgress(frame, scope, reveal),
  series: resolveLineSeries(series, tokens),
);

/// The painter behind `Chart.line`: one polyline per series, each trimmed to
/// [progress] of its length so the line draws on left to right.
///
/// It is an internal type (authors call `Chart.line` / `Chart.line.series`). The
/// chart resolves each [series]' size-independent geometry in `build`; the
/// painter places the pixels from the paint `size`. [totalLength] and
/// [sweptLength] expose the path metrics so the sweep is unit-tested without a
/// pixel readback.
final class LineChartPainter extends ChartPainter {
  /// Creates a line painter over the resolved [series] geometry.
  LineChartPainter({required super.tokens, required super.progress, required this.series})
    : super(plotRect: Rect.zero);

  /// One resolved series geometry per polyline, in draw order.
  final List<LineSeriesGeometry> series;

  /// The number of polylines this painter draws.
  int get seriesCount => series.length;

  /// Each series' resolved color, in draw order.
  List<Color> get colors => [for (final s in series) s.color];

  /// The value-axis maximum shared across every series.
  num get _sharedMax => maxAcross(series);

  /// The value y scale at [size], shared across every series.
  LinearScale valueScale(Size size) => valueScaleFor(size, _sharedMax);

  /// The full (untrimmed) polyline for series [index] at [size].
  Path fullPath(Size size, int index) => polyline(pointsFor(series[index], size, _sharedMax));

  /// The total length of series [index]'s polyline at [size].
  double totalLength(Size size, int index) => pathLength(fullPath(size, index));

  /// The painted length of series [index] at [size] (its total times the
  /// current reveal [progress]).
  double sweptLength(Size size, int index) => totalLength(size, index) * progress.clamp(0.0, 1.0);

  @override
  void paintChart(Canvas canvas, Size size) {
    final plot = ChartPainter.computePlotRect(size, lineGutters);
    drawAxes(canvas, valueScale: valueScale(size), plot: plot, tickCount: 4, tokens: tokens);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _lineStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (var i = 0; i < series.length; i++) {
      stroke.color = series[i].color;
      canvas.drawPath(sweep(fullPath(size, i), progress), stroke);
    }
  }

  @override
  bool shouldRepaint(covariant ChartPainter oldDelegate) =>
      oldDelegate is! LineChartPainter ||
      oldDelegate.progress != progress ||
      oldDelegate.tokens != tokens ||
      !listEquals(oldDelegate.series, series);
}
