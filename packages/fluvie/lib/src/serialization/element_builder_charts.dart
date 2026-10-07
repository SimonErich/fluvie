part of 'element_builder.dart';

/// The chart variants the spec accepts, in the error message's order.
const List<String> _chartVariants = ['bar', 'pie', 'donut', 'line', 'area', 'scatter'];

/// A `Chart` from its spec props: `variant` picks the named factory, and each
/// variant enforces its own data shape (`data` / `series` / `points`) exactly
/// as the widget's factories do.
Widget _chartElement(Map<String, Object?> props) {
  final reveal = props['reveal'] == null
      ? const Time.relative(0.6)
      : decodeTime(props['reveal'], path: const ['reveal']);
  final stagger = props['stagger'] == null
      ? null
      : decodeStagger(props['stagger'], path: const ['stagger']);
  final variant = props['variant'];
  switch (variant) {
    case 'bar':
      _rejectShapes(props, 'bar', const ['series', 'points']);
      return Chart.bar(data: _chartData(props['data']), reveal: reveal, stagger: stagger);
    case 'pie':
      _rejectShapes(props, 'pie', const ['series', 'points']);
      return Chart.pie(data: _chartData(props['data']), reveal: reveal);
    case 'donut':
      _rejectShapes(props, 'donut', const ['series', 'points']);
      return Chart.donut(
        data: _chartData(props['data']),
        reveal: reveal,
        innerRadius: _numOr(props['innerRadius'], 0.6).toDouble(),
      );
    case 'line':
      _requireDataOrSeries(props, 'line');
      if (props['data'] != null) return Chart.line(data: _chartData(props['data']), reveal: reveal);
      return Chart.line.series(_chartSeriesList(props['series']), reveal: reveal);
    case 'area':
      _requireDataOrSeries(props, 'area');
      if (props['data'] != null) return Chart.area(data: _chartData(props['data']), reveal: reveal);
      return Chart.area.series(_chartSeriesList(props['series']), reveal: reveal);
    case 'scatter':
      final shapes = [props['points'], props['data'], props['series']];
      if (shapes.where((shape) => shape != null).length != 1) {
        throw FluvieSpecError(
          'A scatter chart takes exactly one of "points", "data", or "series"',
          path: const ['variant'],
        );
      }
      if (props['points'] != null) {
        return Chart.scatter(
          points: _chartPoints(props['points'], const ['points']),
          reveal: reveal,
          stagger: stagger,
        );
      }
      if (props['data'] != null) {
        return Chart.scatter(data: _chartData(props['data']), reveal: reveal, stagger: stagger);
      }
      final series = _chartSeriesList(props['series']);
      if (series.length != 1) {
        throw FluvieSpecError(
          'A scatter chart takes exactly one series',
          path: const ['series'],
        );
      }
      return Chart.scatter.series(series.single, reveal: reveal, stagger: stagger);
  }
  throw FluvieSpecError(
    'Unknown chart variant "$variant"; expected ${_chartVariants.join(', ')}',
    path: const ['variant'],
  );
}

/// Throws when a data shape a [variant] cannot read is present.
void _rejectShapes(Map<String, Object?> props, String variant, List<String> rejected) {
  for (final shape in rejected) {
    if (props[shape] == null) continue;
    throw FluvieSpecError('A $variant chart takes "data", not "$shape"', path: [shape]);
  }
}

/// Throws unless exactly one of `data` / `series` is present (line / area).
void _requireDataOrSeries(Map<String, Object?> props, String variant) {
  _rejectShapes(props, variant, const ['points']);
  if ((props['data'] == null) == (props['series'] == null)) {
    throw FluvieSpecError(
      'A $variant chart takes exactly one of "data" or "series"',
      path: const ['variant'],
    );
  }
}

/// A category-to-value map: every value must be a number.
Map<String, num> _chartData(Object? raw, [List<String> path = const ['data']]) {
  if (raw is! Map<String, Object?>) {
    throw FluvieSpecError('Expected a "data" map of numbers', path: path);
  }
  return {
    for (final entry in raw.entries)
      entry.key: entry.value is num
          ? entry.value! as num
          : throw FluvieSpecError(
              'Expected a number for "${entry.key}"',
              path: [...path, entry.key],
            ),
  };
}

List<ChartSeries> _chartSeriesList(Object? raw) {
  if (raw is! List || raw.isEmpty) {
    throw FluvieSpecError('Expected a non-empty "series" list', path: const ['series']);
  }
  return [for (var i = 0; i < raw.length; i++) _chartSeries(raw[i], i)];
}

/// One series: a `name`, an optional `color`, and exactly one of a `data` map
/// (`ChartSeries.values`) or a `points` list (`ChartSeries.points`).
ChartSeries _chartSeries(Object? raw, int index) {
  final path = ['series', '$index'];
  if (raw is! Map<String, Object?>) {
    throw FluvieSpecError('Expected a series object', path: path);
  }
  final name = raw['name'];
  if (name is! String) {
    throw FluvieSpecError('A series needs a string "name"', path: [...path, 'name']);
  }
  if ((raw['data'] == null) == (raw['points'] == null)) {
    throw FluvieSpecError(
      'A series takes exactly one of "data" or "points"',
      path: path,
    );
  }
  final color = raw['color'] == null ? null : decodeColor(raw['color'], path: [...path, 'color']);
  if (raw['data'] != null) {
    return ChartSeries.values(
      name: name,
      data: _chartData(raw['data'], [...path, 'data']),
      color: color,
    );
  }
  return ChartSeries.points(
    name: name,
    data: _chartPoints(raw['points'], [...path, 'points']),
    color: color,
  );
}

List<ChartPoint> _chartPoints(Object? raw, List<String> path) {
  if (raw is! List) throw FluvieSpecError('Expected a list of points', path: path);
  return [
    for (var i = 0; i < raw.length; i++) _chartPoint(raw[i], [...path, '$i']),
  ];
}

ChartPoint _chartPoint(Object? raw, List<String> path) {
  if (raw is! Map<String, Object?>) {
    throw FluvieSpecError('Expected a point object {x, y}', path: path);
  }
  final x = raw['x'];
  final y = raw['y'];
  if (x is! num || y is! num) {
    throw FluvieSpecError('A point needs numbers "x" and "y"', path: path);
  }
  final label = raw['label'];
  return ChartPoint(x: x, y: y, label: label is String ? label : null);
}
