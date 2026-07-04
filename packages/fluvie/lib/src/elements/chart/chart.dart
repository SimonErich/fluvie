/// @docImport 'package:fluvie/src/theme/fluvie_tokens_scope.dart';
library;

import 'package:flutter/widgets.dart'
    show BuildContext, Color, CustomPaint, Key, SizedBox, StatelessWidget, Widget;
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/chart/area_chart.dart';
import 'package:fluvie/src/elements/chart/bar_chart.dart';
import 'package:fluvie/src/elements/chart/data/chart_point.dart';
import 'package:fluvie/src/elements/chart/data/chart_series.dart';
import 'package:fluvie/src/elements/chart/line_chart.dart';
import 'package:fluvie/src/elements/chart/painter/chart_painter.dart';
import 'package:fluvie/src/elements/chart/pie_chart.dart';
import 'package:fluvie/src/elements/chart/scatter_chart.dart';
import 'package:fluvie/src/elements/runtime/element_shared.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/theme/build_context_tokens.dart';
import 'package:fluvie/src/theme/fluvie_tokens.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

part 'chart_internals.dart';

/// The kind of chart a [Chart] paints; one private discriminator keeps the
/// public surface a single type with named factories.
enum _ChartKind { bar, line, area, pie, donut, scatter }

/// The chart family — an intrinsic, frame-driven element whose reveal is built
/// into its own constructor.
///
/// `Chart` is one public type with named factories per chart shape:
///
/// ```dart
/// Chart.bar(data: {'Jan': 30, 'Feb': 45}, reveal: 0.6.relative)
/// Chart.line(data: {'Jan': 30, 'Feb': 45}, reveal: 0.6.relative)
/// Chart.line.series([ChartSeries.values(name: 'Sales', data: {...})])
/// ```
///
/// Like `Counter` and `Typewriter`, a chart reads the frame clock and its time
/// scope, computes a `0 -> 1` reveal progress against its own window, and paints
/// a `CustomPaint`. The reveal (`reveal` / `reveal`) is a [Time] resolved
/// against the element window, exactly as `Counter.duration` is. Outer
/// transforms ride `.animate()` — the constructor takes content parameters
/// only. A [shared] anchor wraps the chart in a `SharedElement` for a hero morph
/// across a scene boundary.
///
/// Charts are pure functions of `(data, reveal progress, theme tokens)`: two
/// builds at the same frame paint identical pixels. Color comes from
/// `context.fluvie`, so wrapping a chart in a [FluvieTokensScope] (or the
/// `FluvieTheme`) themes it; with no scope it uses the package
/// `FluvieTokens.fallback` palette. A per-series `color:` override wins.
///
/// Two durations can meet on a chart: [reveal] times the intrinsic reveal
/// (grow, draw, sweep, pop), while transforms and opacity ride `.animate()`
/// with their own timing.
final class Chart extends StatelessWidget {
  const Chart._({
    required this._kind,
    required this.reveal,
    this.data,
    this.series,
    this.points,
    this.stagger,
    this.innerRadius = 0,
    this.color,
    this.shared,
    super.key,
  });

  /// A bar (column) chart over an ordered category to value [data] map.
  ///
  /// Each bar grows from the baseline by `value x ease(progress)` over [reveal]
  /// (default a `0.6` relative window). An optional [stagger] delays each bar's
  /// growth so the columns rise in a wave. [shared] wraps the chart in a
  /// `SharedElement`.
  factory Chart.bar({
    required Map<String, num> data,
    Time reveal = const Time.relative(0.6),
    Stagger? stagger,
    Anchor? shared,
    Key? key,
  }) => Chart._(
    kind: _ChartKind.bar,
    reveal: reveal,
    data: data,
    stagger: stagger,
    shared: shared,
    key: key,
  );

  /// A pie chart whose segments sweep clockwise from 12 o'clock.
  ///
  /// Each segment's angle is proportional to its value, and the whole disc
  /// sweeps angularly over [reveal] (default a `0.6` relative window) so the pie
  /// fills in. Segment colors cycle the theme palette. [shared] wraps the chart
  /// in a `SharedElement`.
  factory Chart.pie({
    required Map<String, num> data,
    Time reveal = const Time.relative(0.6),
    Anchor? shared,
    Key? key,
  }) => Chart._(kind: _ChartKind.pie, reveal: reveal, data: data, shared: shared, key: key);

  /// A donut chart: a [Chart.pie] with an inner-radius hole.
  ///
  /// [innerRadius] is the hole radius as a fraction of the outer radius, in
  /// `(0, 1)` (a smaller value leaves a thicker ring). The hole is cut with an
  /// even-odd ring path, never a `saveLayer`, so the draw stays capture-safe.
  /// Everything else matches [Chart.pie].
  factory Chart.donut({
    required Map<String, num> data,
    Time reveal = const Time.relative(0.6),
    double innerRadius = 0.6,
    Anchor? shared,
    Key? key,
  }) => Chart._(
    kind: _ChartKind.donut,
    reveal: reveal,
    data: data,
    innerRadius: innerRadius,
    shared: shared,
    key: key,
  );

  /// A line chart that draws its polyline on left to right.
  ///
  /// Call it as `Chart.line(data: {...}, reveal: ...)` for a single series, or
  /// `Chart.line.series([...])` for several colored polylines. The line is
  /// trimmed to the reveal progress, so it draws on over its `reveal` window.
  static const ChartLineFactory line = ChartLineFactory._();

  /// An area chart that fills under its sweeping line.
  ///
  /// Call it as `Chart.area(data: {...}, reveal: ...)` for a single series, or
  /// `Chart.area.series([...])` for several stacked fills. The fill follows the
  /// line sweep and closes to the value baseline.
  static const ChartAreaFactory area = ChartAreaFactory._();

  /// A scatter chart whose markers pop in with a spring scale.
  ///
  /// Call it as `Chart.scatter(points: [...])` for explicit `(x, y)` points,
  /// `Chart.scatter(data: {...})` for a category → value map (the category index
  /// is the x), or `Chart.scatter.series([...])` for an explicit colored series.
  /// Each marker's scale springs `0 -> 1` with an overshoot over its `reveal`
  /// window; an optional `stagger` offsets each point's pop so the markers pop
  /// in a wave.
  static const ChartScatterFactory scatter = ChartScatterFactory._();

  final _ChartKind _kind;

  /// The reveal window resolved against the element scope (`reveal` / `reveal`).
  final Time reveal;

  /// The single-series category to value data, or `null` for a multi-series
  /// chart built with a `.series` factory.
  final Map<String, num>? data;

  /// The multi-series data, or `null` for a single-series chart.
  final List<ChartSeries>? series;

  /// The scatter `(x, y)` points, or `null` for every non-scatter chart.
  final List<ChartPoint>? points;

  /// The optional per-segment reveal stagger (bars / scatter), or `null`.
  final Stagger? stagger;

  /// The donut hole radius as a fraction of the outer radius; `0` for every
  /// non-donut chart.
  final double innerRadius;

  /// The explicit marker color for a scatter chart, or `null` to cycle the
  /// palette.
  final Color? color;

  /// The optional hero anchor; non-null wraps the chart in a `SharedElement`.
  final Anchor? shared;

  @override
  Widget build(BuildContext context) {
    final frame = FrameProvider.of(context).frame;
    final scope = TimeScopeProvider.of(context);
    final tokens = context.fluvie;
    final visible = CustomPaint(
      painter: _painterFor(frame, scope, tokens),
      child: const SizedBox.expand(),
    );
    return wrapShared(shared, visible);
  }
}
