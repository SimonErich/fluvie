part of 'chart.dart';

/// The painter-resolution machinery for [Chart], kept in this part so the public
/// [Chart] class file stays a lean named-factory surface. A private extension
/// can read [Chart]'s private fields because parts share the defining library.
extension _ChartPainters on Chart {
  /// This chart's series, resolving single-series `data` into one [ChartSeries].
  List<ChartSeries> get _resolvedSeries =>
      series ?? [ChartSeries.values(name: '', data: data ?? const {})];

  /// This chart's scatter points: explicit `points`, a series' points, or the
  /// single-series `data` map mapped to category-index points.
  List<ChartPoint> get _resolvedPoints =>
      points ?? series?.first.points ?? scatterPointsFromData(data ?? const {});

  /// The resolved painter for this chart's kind at [frame] within [scope],
  /// colored by the [tokens] resolved from `context.fluvie`.
  ChartPainter _painterFor(int frame, TimeScopeData scope, FluvieTokens tokens) => switch (_kind) {
    _ChartKind.bar => buildBarPainter(
      frame: frame,
      scope: scope,
      data: data ?? const {},
      reveal: reveal,
      stagger: stagger,
      tokens: tokens,
    ),
    _ChartKind.line => buildLinePainter(
      frame: frame,
      scope: scope,
      series: _resolvedSeries,
      reveal: reveal,
      tokens: tokens,
    ),
    _ChartKind.area => buildAreaPainter(
      frame: frame,
      scope: scope,
      series: _resolvedSeries,
      reveal: reveal,
      tokens: tokens,
    ),
    _ChartKind.pie => buildPiePainter(
      frame: frame,
      scope: scope,
      data: data ?? const {},
      reveal: reveal,
      tokens: tokens,
    ),
    _ChartKind.donut => buildPiePainter(
      frame: frame,
      scope: scope,
      data: data ?? const {},
      reveal: reveal,
      innerRadius: innerRadius,
      tokens: tokens,
    ),
    _ChartKind.scatter => buildScatterPainter(
      frame: frame,
      scope: scope,
      points: _resolvedPoints,
      reveal: reveal,
      stagger: stagger,
      color: color,
      tokens: tokens,
    ),
  };
}

/// The callable behind `Chart.line`: invoke it for a single series, or call
/// [series] for several colored polylines.
final class ChartLineFactory {
  const ChartLineFactory._();

  /// A single-series line chart over [data], drawn on over [drawIn].
  Chart call({
    required Map<String, num> data,
    Time drawIn = const Time.relative(0.6),
    Anchor? shared,
    Key? key,
  }) => Chart._(kind: _ChartKind.line, reveal: drawIn, data: data, shared: shared, key: key);

  /// A multi-series line chart over [series], each a colored polyline.
  Chart series(
    List<ChartSeries> series, {
    Time drawIn = const Time.relative(0.6),
    Anchor? shared,
    Key? key,
  }) => Chart._(kind: _ChartKind.line, reveal: drawIn, series: series, shared: shared, key: key);
}

/// The callable behind `Chart.area`: invoke it for a single series, or call
/// [series] for several stacked fills.
final class ChartAreaFactory {
  const ChartAreaFactory._();

  /// A single-series area chart over [data], filled on over [drawIn].
  Chart call({
    required Map<String, num> data,
    Time drawIn = const Time.relative(0.6),
    Anchor? shared,
    Key? key,
  }) => Chart._(kind: _ChartKind.area, reveal: drawIn, data: data, shared: shared, key: key);

  /// A multi-series area chart over [series], each a filled region.
  Chart series(
    List<ChartSeries> series, {
    Time drawIn = const Time.relative(0.6),
    Anchor? shared,
    Key? key,
  }) => Chart._(kind: _ChartKind.area, reveal: drawIn, series: series, shared: shared, key: key);
}

/// The callable behind `Chart.scatter`: invoke it with explicit `points` or a
/// category → value `data` map, or call [series] for a colored point series.
final class ChartScatterFactory {
  const ChartScatterFactory._();

  /// A scatter chart over explicit [points] or a category → value [data] map
  /// (exactly one is non-null), each marker popping in over [popIn].
  ///
  /// With [data], the category index is the x and the value is the y. An
  /// optional [stagger] offsets each point's pop so the markers pop in a wave.
  Chart call({
    List<ChartPoint>? points,
    Map<String, num>? data,
    Time popIn = const Time.relative(0.6),
    Stagger? stagger,
    Anchor? shared,
    Key? key,
  }) {
    assert(
      (points == null) != (data == null),
      'Chart.scatter needs exactly one of points: or data:',
    );
    return Chart._(
      kind: _ChartKind.scatter,
      reveal: popIn,
      points: points,
      data: data,
      stagger: stagger,
      shared: shared,
      key: key,
    );
  }

  /// A scatter chart over a single colored point [series], popping in over
  /// [popIn] with an optional [stagger].
  Chart series(
    ChartSeries series, {
    Time popIn = const Time.relative(0.6),
    Stagger? stagger,
    Anchor? shared,
    Key? key,
  }) => Chart._(
    kind: _ChartKind.scatter,
    reveal: popIn,
    series: [series],
    color: series.color,
    stagger: stagger,
    shared: shared,
    key: key,
  );
}
