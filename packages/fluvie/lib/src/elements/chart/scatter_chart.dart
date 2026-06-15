import 'dart:ui' show Canvas, Color, Offset, Paint, Rect, Size;

import 'package:flutter/animation.dart' show Curve;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:fluvie/src/animation/stagger/stagger_offsets.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/chart/data/chart_point.dart';
import 'package:fluvie/src/elements/chart/painter/chart_painter.dart';
import 'package:fluvie/src/elements/chart/scale/chart_scale.dart';
import 'package:fluvie/src/elements/reveal/reveal_progress.dart';
import 'package:fluvie/src/theme/fluvie_tokens.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

/// The plot gutters a scatter chart insets by, matching the bar / line charts.
const ChartGutters scatterGutters = ChartGutters(left: 8, top: 8, right: 8, bottom: 8);

/// The marker radius (at full pop scale) as a fraction of the plot's smaller
/// dimension, so a point reads clearly without crowding its neighbors.
const double _markerFraction = 0.04;

/// Builds the [ScatterChartPainter] for `Chart.scatter` at [frame] within
/// [scope] — the data-transform layer that resolves the points, the per-point
/// pop progress (optionally staggered), and the palette color, leaving pixel
/// placement to the painter.
///
/// Each point's scale springs `0 -> 1` with an overshoot via [Ease.elastic]
/// applied to its pop progress; a [stagger] offsets each point's pop so the
/// markers pop in a wave. Points carry their `(x, y)` value so the painter
/// places them with [LinearScale]s built from the value extents.
ScatterChartPainter buildScatterPainter({
  required int frame,
  required TimeScopeData scope,
  required List<ChartPoint> points,
  required Time reveal,
  Stagger? stagger,
  Color? color,
  FluvieTokens tokens = const FluvieTokens.fallback(),
}) {
  final elapsed = frame - scope.startFrame;
  final revealFrames = reveal.resolveFrames(scope);
  final progress = stagger == null
      ? [for (var i = 0; i < points.length; i++) revealProgress(frame, scope, reveal)]
      : staggeredRevealProgress(
          elapsed: elapsed,
          offsets: staggerOffsetFrames(stagger: stagger, childCount: points.length, scope: scope),
          perSegmentFrames: revealFrames,
        );
  return ScatterChartPainter(
    tokens: tokens,
    progress: revealProgress(frame, scope, reveal),
    points: points,
    pointProgress: progress,
    color: color ?? tokens.palette.colorAt(0),
  );
}

/// The painter behind `Chart.scatter`: one marker per point, each placed at its
/// `(x, y)` value and scaled by a spring pop (`0 -> 1` with an overshoot
/// mid-pop).
///
/// It is an internal type (authors call `Chart.scatter`). The chart resolves the
/// size-independent points and per-point pop progress in `build`; the painter
/// places the pixels with [LinearScale]s built from the value extents. [scales]
/// and [centersFor] expose the resolved geometry so the pop and placement are
/// unit-tested without a pixel readback.
final class ScatterChartPainter extends ChartPainter {
  /// Creates a scatter painter over the resolved [points] and [pointProgress].
  ScatterChartPainter({
    required super.tokens,
    required super.progress,
    required this.points,
    required this.pointProgress,
    required this.color,
    this.ease = Ease.elastic,
  }) : super(plotRect: Rect.zero);

  /// The points to plot, in draw order.
  final List<ChartPoint> points;

  /// One reveal progress in `[0, 1]` per point, already staggered.
  final List<double> pointProgress;

  /// The marker fill color (a palette slot or an explicit override).
  final Color color;

  /// The curve each point's pop follows; [Ease.elastic] overshoots mid-pop.
  final Curve ease;

  /// Each point's pop scale at the current progress: `ease(pointProgress)`, so a
  /// spring overshoot crosses above `1` before settling to `1`.
  List<double> get scales => [
    for (final p in pointProgress) ease.transform(p.clamp(0.0, 1.0)),
  ];

  /// The x value scale across [size]'s plot rect.
  LinearScale xScale(Size size) {
    final plot = ChartPainter.computePlotRect(size, scatterGutters);
    final xs = points.map((p) => p.x);
    return LinearScale.niceBounds(
      min: xs.isEmpty ? 0 : xs.reduce((a, b) => a < b ? a : b),
      max: xs.isEmpty ? 0 : xs.reduce((a, b) => a > b ? a : b),
      pixelMin: plot.left,
      pixelMax: plot.right,
    );
  }

  /// The y value scale (an upward axis) across [size]'s plot rect.
  LinearScale yScale(Size size) {
    final plot = ChartPainter.computePlotRect(size, scatterGutters);
    final ys = points.map((p) => p.y);
    return LinearScale.niceBounds(
      min: ys.isEmpty ? 0 : ys.reduce((a, b) => a < b ? a : b),
      max: ys.isEmpty ? 0 : ys.reduce((a, b) => a > b ? a : b),
      pixelMin: plot.bottom,
      pixelMax: plot.top,
    );
  }

  /// Each point's pixel center at [size], in draw order.
  List<Offset> centersFor(Size size) {
    final x = xScale(size);
    final y = yScale(size);
    return [for (final p in points) Offset(x.toPixel(p.x), y.toPixel(p.y))];
  }

  /// The marker base radius at [size] (before the pop scale).
  double markerRadius(Size size) =>
      (size.width < size.height ? size.width : size.height) * _markerFraction;

  @override
  void paintChart(Canvas canvas, Size size) {
    final centers = centersFor(size);
    final base = markerRadius(size);
    final scaleValues = scales;
    final paint = Paint()..color = color;
    for (var i = 0; i < centers.length; i++) {
      final radius = base * scaleValues[i];
      if (radius <= 0) continue;
      canvas.drawCircle(centers[i], radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ChartPainter oldDelegate) =>
      oldDelegate is! ScatterChartPainter ||
      oldDelegate.progress != progress ||
      oldDelegate.tokens != tokens ||
      oldDelegate.color != color ||
      !listEquals(oldDelegate.pointProgress, pointProgress);
}

/// Resolves a single-series category → value [data] map into points whose x is
/// the category index and y is the value, preserving order.
List<ChartPoint> scatterPointsFromData(Map<String, num> data) {
  final keys = data.keys.toList();
  return [
    for (var i = 0; i < keys.length; i++) ChartPoint(x: i, y: data[keys[i]]!, label: keys[i]),
  ];
}
