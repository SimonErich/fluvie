import 'dart:ui' show Canvas, Offset, Paint, PaintingStyle, Path, Rect, Size;

import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/chart/data/chart_series.dart';
import 'package:fluvie/src/elements/chart/painter/axis_painter.dart';
import 'package:fluvie/src/elements/chart/painter/chart_painter.dart';
import 'package:fluvie/src/elements/chart/render/line_geometry.dart';
import 'package:fluvie/src/elements/chart/scale/chart_scale.dart';
import 'package:fluvie/src/elements/reveal/reveal_progress.dart';
import 'package:fluvie/src/theme/fluvie_tokens.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

/// The opacity an area fill draws at, so overlapping series stay readable.
const double _fillOpacity = 0.55;

/// Builds the [AreaChartPainter] for `Chart.area` at [frame] within [scope] —
/// the data-transform layer that resolves each series and the shared reveal
/// progress, leaving pixel placement to the painter.
AreaChartPainter buildAreaPainter({
  required int frame,
  required TimeScopeData scope,
  required List<ChartSeries> series,
  required Time reveal,
  FluvieTokens tokens = const FluvieTokens.fallback(),
}) => AreaChartPainter(
  tokens: tokens,
  progress: revealProgress(frame, scope, reveal),
  series: resolveLineSeries(series, tokens),
);

/// The painter behind `Chart.area`: one filled region per series, following the
/// line sweep and closing to the value baseline.
///
/// It is an internal type (authors call `Chart.area` / `Chart.area.series`). The
/// fill fills *under* the advancing line: the swept polyline points close down
/// to the baseline at the sweep's leading x, so the region grows with
/// [progress]. [fillPath] and [fillArea] expose the resolved geometry so the
/// fill is unit-tested without a pixel readback.
final class AreaChartPainter extends ChartPainter {
  /// Creates an area painter over the resolved [series] geometry.
  AreaChartPainter({required super.tokens, required super.progress, required this.series})
    : super(plotRect: Rect.zero);

  /// One resolved series geometry per filled region, in draw order.
  final List<LineSeriesGeometry> series;

  /// The number of filled regions this painter draws.
  int get seriesCount => series.length;

  /// The value-axis maximum shared across every series.
  num get _sharedMax => maxAcross(series);

  /// The value y scale at [size], shared across every series.
  LinearScale valueScale(Size size) => valueScaleFor(size, _sharedMax);

  /// The closed fill path for series [index] at [size] and the current sweep.
  ///
  /// It follows the swept polyline, then drops to the value
  /// [LinearScale.baselinePixel] at the sweep's leading x and the series' first
  /// x, closing the region. An unstarted sweep yields an empty path.
  Path fillPath(Size size, int index) {
    final value = valueScale(size);
    final points = pointsFor(series[index], size, _sharedMax);
    final swept = sweptPoints(points, progress);
    final path = Path();
    if (swept.isEmpty) return path;
    final baseline = value.baselinePixel;
    path.moveTo(swept.first.dx, baseline);
    for (final point in swept) {
      path.lineTo(point.dx, point.dy);
    }
    return path
      ..lineTo(swept.last.dx, baseline)
      ..close();
  }

  /// The signed-area magnitude of series [index]'s fill path at [size], a
  /// progress-monotone proxy for "how much is filled" (zero before the sweep
  /// starts).
  double fillArea(Size size, int index) {
    final value = valueScale(size);
    final points = pointsFor(series[index], size, _sharedMax);
    final swept = sweptPoints(points, progress);
    if (swept.length < 2) return 0;
    final baseline = value.baselinePixel;
    final poly = <Offset>[
      Offset(swept.first.dx, baseline),
      ...swept,
      Offset(swept.last.dx, baseline),
    ];
    var sum = 0.0;
    for (var i = 0; i < poly.length; i++) {
      final a = poly[i];
      final b = poly[(i + 1) % poly.length];
      sum += a.dx * b.dy - b.dx * a.dy;
    }
    return sum.abs() / 2;
  }

  @override
  void paintChart(Canvas canvas, Size size) {
    final plot = ChartPainter.computePlotRect(size, lineGutters);
    drawAxes(canvas, valueScale: valueScale(size), plot: plot, tickCount: 4, tokens: tokens);
    final fill = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < series.length; i++) {
      fill.color = series[i].color.withValues(alpha: _fillOpacity);
      canvas.drawPath(fillPath(size, i), fill);
    }
  }

  @override
  bool shouldRepaint(covariant ChartPainter oldDelegate) =>
      oldDelegate is! AreaChartPainter ||
      oldDelegate.progress != progress ||
      oldDelegate.tokens != tokens ||
      oldDelegate.seriesCount != seriesCount;
}
