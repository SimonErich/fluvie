/// @docImport 'package:fluvie/src/elements/chart/data/chart_series.dart';
library;

import 'package:meta/meta.dart' show immutable;

/// One `(x, y)` sample in a chart series, with an optional [label] (decision
/// D4).
///
/// A point is the backing shape for scatter series and any chart that places
/// data in a two-dimensional value space (rather than a category → value map).
/// It holds only numbers and a string, so it lives under `elements/chart/data/`
/// alongside [ChartSeries] — the chart owns its data shapes, they are not a
/// cross-layer currency in `core`.
///
/// Two points are equal when [x], [y], and [label] all match, which keeps frame
/// caching honest (identical data → identical geometry → cacheable frames).
///
/// ```dart
/// const ChartPoint(x: 12, y: 4.5, label: 'Q1')
/// ```
@immutable
final class ChartPoint {
  /// Creates a point at ([x], [y]) with an optional [label].
  const ChartPoint({required this.x, required this.y, this.label});

  /// The point's horizontal value, in data units (not pixels).
  final num x;

  /// The point's vertical value, in data units (not pixels).
  final num y;

  /// An optional human label for this point, or `null` when unlabeled.
  final String? label;

  @override
  bool operator ==(Object other) =>
      other is ChartPoint && other.x == x && other.y == y && other.label == label;

  @override
  int get hashCode => Object.hash(ChartPoint, x, y, label);

  @override
  String toString() => 'ChartPoint(x: $x, y: $y, label: $label)';
}
