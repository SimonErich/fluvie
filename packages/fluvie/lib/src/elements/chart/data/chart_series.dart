import 'package:flutter/foundation.dart' show listEquals, mapEquals;
import 'package:flutter/painting.dart' show Color;
import 'package:fluvie/src/elements/chart/data/chart_point.dart';
import 'package:meta/meta.dart' show immutable;

/// One named, optionally colored series of chart data.
///
/// A series carries its data in one of two shapes, chosen by the named factory:
///
/// * [ChartSeries.values] — an ordered category → value [data] map, the shape
///   bar / line / area charts read (insertion order is the category order).
/// * [ChartSeries.points] — a list of `(x, y)` [points], the shape scatter
///   reads.
///
/// Exactly one of [data] / [points] is non-null for any series. An optional
/// [color] overrides the theme palette slot the chart would otherwise pick;
/// `null` means "let the chart cycle the palette."
///
/// The type holds only Flutter-math types ([Color]) plus its data, so it lives
/// under `elements/chart/data/`. Two series are equal when their name, color,
/// and data all match (with deep map / list equality), which keeps frame
/// caching honest.
///
/// ```dart
/// const ChartSeries.values(name: 'Sales', data: {'Jan': 30, 'Feb': 45})
/// const ChartSeries.points(name: 'Cloud', data: [ChartPoint(x: 1, y: 2)])
/// ```
@immutable
final class ChartSeries {
  /// The shared const constructor; the named factories pin which data shape a
  /// series carries rather than exposing this directly.
  const ChartSeries._({required this.name, this.data, this.points, this.color});

  /// A category → value series named [name], optionally [color]ed.
  ///
  /// The [data] map's insertion order is the category order the chart draws.
  const ChartSeries.values({
    required String name,
    required Map<String, num> data,
    Color? color,
  }) : this._(name: name, data: data, color: color);

  /// An `(x, y)` point series named [name], optionally [color]ed.
  ///
  /// The named parameter is `data` (a `List<ChartPoint>`) for call-site
  /// symmetry with [ChartSeries.values]; it is exposed through [points].
  const ChartSeries.points({
    required String name,
    required List<ChartPoint> data,
    Color? color,
  }) : this._(name: name, points: data, color: color);

  /// The series name, shown in legends and used to identify it.
  final String name;

  /// The category → value data, or `null` for a [ChartSeries.points] series.
  final Map<String, num>? data;

  /// The `(x, y)` points, or `null` for a [ChartSeries.values] series.
  final List<ChartPoint>? points;

  /// The explicit series color, or `null` to cycle the theme palette.
  final Color? color;

  @override
  bool operator ==(Object other) =>
      other is ChartSeries &&
      other.name == name &&
      other.color == color &&
      mapEquals(other.data, data) &&
      listEquals(other.points, points);

  @override
  int get hashCode => Object.hash(
    ChartSeries,
    name,
    color,
    data == null ? null : Object.hashAll(data!.entries.map((e) => Object.hash(e.key, e.value))),
    points == null ? null : Object.hashAll(points!),
  );

  @override
  String toString() => 'ChartSeries(name: $name)';
}
