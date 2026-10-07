part of 'dart_spec_printer.dart';

/// A `Chart.<variant>(...)` call, mirroring `_chartElement` in fluvie's
/// builder: `line`/`area` call the factory (or its `.series`) exactly like
/// user code, and `scatter` picks the shape its JSON carries.
String _chartElement(Map<String, Object?> element) {
  final reveal = element['reveal'] == null
      ? null
      : 'reveal: ${_time(element['reveal']! as String)}';
  final stagger = element['stagger'] == null
      ? null
      : 'stagger: ${_stagger(_map(element['stagger']))}';
  String data() => 'data: ${_chartDataMap(_map(element['data']))}';
  String seriesList() {
    final series = element['series']! as List;
    return '[${series.map((entry) => _chartSeries(_map(entry))).join(', ')}]';
  }

  switch (element['variant']) {
    case 'bar':
      return 'Chart.bar(${_args([data(), reveal, stagger])})';
    case 'pie':
      return 'Chart.pie(${_args([data(), reveal])})';
    case 'donut':
      return 'Chart.donut(${_args([
        data(),
        reveal,
        _numArg('innerRadius', element['innerRadius']),
      ])})';
    case 'line':
    case 'area':
      final variant = element['variant']! as String;
      if (element['data'] != null) return 'Chart.$variant(${_args([data(), reveal])})';
      return 'Chart.$variant.series(${_args([seriesList(), reveal])})';
    case 'scatter':
      if (element['points'] != null) {
        final points = element['points']! as List;
        return 'Chart.scatter(${_args([
          'points: [${points.map((point) => _chartPoint(_map(point))).join(', ')}]',
          reveal,
          stagger,
        ])})';
      }
      if (element['data'] != null) return 'Chart.scatter(${_args([data(), reveal, stagger])})';
      final series = element['series']! as List;
      return 'Chart.scatter.series(${_args([
        _chartSeries(_map(series.single)),
        reveal,
        stagger,
      ])})';
  }
  throw FormatException('Unknown chart variant "${element['variant']}"');
}

/// A `{'Jan': 30, ...}` map literal over a category-to-value data object.
String _chartDataMap(Map<String, Object?> data) =>
    '{${data.entries.map((entry) => '${_str(entry.key)}: ${_num(entry.value)}').join(', ')}}';

/// A `ChartSeries.values(...)`/`ChartSeries.points(...)` literal.
String _chartSeries(Map<String, Object?> series) {
  final name = 'name: ${_str(series['name']! as String)}';
  final color = series['color'] == null ? null : 'color: ${_color(series['color'])}';
  if (series['data'] != null) {
    return 'ChartSeries.values(${_args([
      name,
      'data: ${_chartDataMap(_map(series['data']))}',
      color,
    ])})';
  }
  final points = series['points']! as List;
  return 'ChartSeries.points(${_args([
    name,
    'data: [${points.map((point) => _chartPoint(_map(point))).join(', ')}]',
    color,
  ])})';
}

/// A `ChartPoint(x: ..., y: ..., label: ...)` literal.
String _chartPoint(Map<String, Object?> point) =>
    'ChartPoint(${_args([
      'x: ${_num(point['x'])}',
      'y: ${_num(point['y'])}',
      if (point['label'] != null) 'label: ${_str(point['label']! as String)}',
    ])})';
