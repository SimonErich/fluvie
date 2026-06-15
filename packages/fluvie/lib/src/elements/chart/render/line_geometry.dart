/// @docImport 'package:fluvie/src/elements/chart/area_chart.dart';
/// @docImport 'package:fluvie/src/elements/chart/line_chart.dart';
library;

import 'dart:ui' show Color, Offset, Path, Size;

import 'package:fluvie/src/elements/chart/data/chart_series.dart';
import 'package:fluvie/src/elements/chart/painter/chart_painter.dart';
import 'package:fluvie/src/elements/chart/scale/chart_scale.dart';
import 'package:fluvie/src/theme/fluvie_tokens.dart';

/// The plot gutters line / area charts inset by, shared with the bar chart.
const ChartGutters lineGutters = ChartGutters(left: 8, top: 8, right: 8, bottom: 8);

/// One series' resolved drawing data for a line / area chart.
///
/// It holds the size-independent inputs — the ordered category [keys], the
/// per-category [values], and the resolved [color] — so the pixel polyline is
/// rebuilt from any paint `size`. Both [LineChartPainter] and [AreaChartPainter]
/// read it, sharing the scale / path math (the DRY guardrail).
final class LineSeriesGeometry {
  /// Creates geometry for the series named by its [color], over [keys] and
  /// [values] (one value per key, in key order).
  const LineSeriesGeometry({required this.keys, required this.values, required this.color});

  /// The ordered category keys, left to right.
  final List<String> keys;

  /// Each category's value, in key order.
  final List<num> values;

  /// The resolved series color (a palette slot or an explicit override).
  final Color color;
}

/// Resolves one [LineSeriesGeometry] per series, with a shared category order
/// (the first series' keys) and palette colors cycled by index.
List<LineSeriesGeometry> resolveLineSeries(List<ChartSeries> series, FluvieTokens tokens) {
  final keys = series.isEmpty ? const <String>[] : series.first.data!.keys.toList();
  return [
    for (var i = 0; i < series.length; i++)
      LineSeriesGeometry(
        keys: keys,
        values: [for (final key in keys) series[i].data![key] ?? 0],
        color: series[i].color ?? tokens.palette.colorAt(i),
      ),
  ];
}

/// The largest value across every [series], the shared value-axis maximum.
num maxAcross(List<LineSeriesGeometry> series) {
  var max = 0.0;
  for (final s in series) {
    for (final v in s.values) {
      if (v > max) max = v.toDouble();
    }
  }
  return max;
}

/// The categorical x scale across [size]'s plot for the shared [keys].
CategoryScale categoryScaleFor(Size size, List<String> keys) {
  final plot = ChartPainter.computePlotRect(size, lineGutters);
  return CategoryScale(categories: keys, pixelMin: plot.left, pixelMax: plot.right);
}

/// The value y scale (upward axis) across [size]'s plot for the data [max].
LinearScale valueScaleFor(Size size, num max) {
  final plot = ChartPainter.computePlotRect(size, lineGutters);
  return LinearScale.niceBounds(min: 0, max: max, pixelMin: plot.bottom, pixelMax: plot.top);
}

/// The pixel points for [geometry] at [size], in left-to-right key order.
List<Offset> pointsFor(LineSeriesGeometry geometry, Size size, num sharedMax) {
  final category = categoryScaleFor(size, geometry.keys);
  final value = valueScaleFor(size, sharedMax);
  return [
    for (var i = 0; i < geometry.keys.length; i++)
      Offset(category.centerOf(geometry.keys[i])!, value.toPixel(geometry.values[i])),
  ];
}

/// The full polyline connecting [points] (an empty / single point yields an
/// empty path with no length).
Path polyline(List<Offset> points) {
  final path = Path();
  if (points.length < 2) return path;
  path.moveTo(points.first.dx, points.first.dy);
  for (final point in points.skip(1)) {
    path.lineTo(point.dx, point.dy);
  }
  return path;
}

/// The total length of [path] (the sum of its metric lengths).
double pathLength(Path path) {
  var total = 0.0;
  for (final metric in path.computeMetrics()) {
    total += metric.length;
  }
  return total;
}

/// [path] trimmed to [progress] of its total length, swept left to right.
Path sweep(Path path, double progress) {
  final result = Path();
  final clamped = progress.clamp(0.0, 1.0);
  for (final metric in path.computeMetrics()) {
    result.addPath(metric.extractPath(0, metric.length * clamped), Offset.zero);
  }
  return result;
}

/// The polyline [points] trimmed to [progress] of the full length, with the
/// final point interpolated along the segment the sweep ends on.
///
/// Returns the leading whole vertices the sweep has passed plus one
/// interpolated endpoint, so a partial area fill follows the advancing line
/// exactly. A [progress] of `0` (or fewer than two points) yields an empty list.
List<Offset> sweptPoints(List<Offset> points, double progress) {
  final clamped = progress.clamp(0.0, 1.0);
  if (points.length < 2 || clamped == 0) return const [];
  final lengths = [
    for (var i = 1; i < points.length; i++) (points[i] - points[i - 1]).distance,
  ];
  final total = lengths.fold<double>(0, (a, b) => a + b);
  if (total == 0) return [points.first];
  final target = total * clamped;
  final result = <Offset>[points.first];
  var travelled = 0.0;
  for (var i = 0; i < lengths.length; i++) {
    if (travelled + lengths[i] >= target) {
      final t = lengths[i] == 0 ? 0.0 : (target - travelled) / lengths[i];
      result.add(Offset.lerp(points[i], points[i + 1], t)!);
      return result;
    }
    travelled += lengths[i];
    result.add(points[i + 1]);
  }
  return result;
}
