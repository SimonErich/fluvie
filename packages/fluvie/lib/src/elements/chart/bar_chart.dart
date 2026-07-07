import 'dart:ui' show Canvas, Color, Paint, Rect, Size;

import 'package:flutter/animation.dart' show Curve;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:fluvie/src/animation/stagger/stagger_offsets.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/chart/painter/axis_painter.dart';
import 'package:fluvie/src/elements/chart/painter/chart_painter.dart';
import 'package:fluvie/src/elements/chart/scale/chart_scale.dart';
import 'package:fluvie/src/elements/reveal/reveal_progress.dart';
import 'package:fluvie/src/theme/fluvie_tokens.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

/// The plot gutters every bar / line / area chart insets by.
const ChartGutters chartGutters = ChartGutters(left: 8, top: 8, right: 8, bottom: 8);

/// The fraction of each band removed as inter-bar gap.
const double _barPadding = 0.3;

/// Builds the [BarChartPainter] for `Chart.bar` at [frame] within [scope].
///
/// This is the chart's data-transform layer: it resolves the value
/// domain over [data], computes one staggered reveal progress per bar (via
/// [staggerOffsetFrames] and [staggeredRevealProgress] when [stagger] is given,
/// or one shared [revealProgress] otherwise), and cycles the [tokens]
/// palette for colors. The size-dependent pixel scales are deferred to the
/// painter so the same painter paints correctly at any layout size.
BarChartPainter buildBarPainter({
  required int frame,
  required TimeScopeData scope,
  required Map<String, num> data,
  required Time reveal,
  Stagger? stagger,
  FluvieTokens tokens = const FluvieTokens.fallback(),
}) {
  final categories = data.keys.toList();
  final values = [for (final key in categories) data[key]!];
  final elapsed = frame - scope.startFrame;
  final revealFrames = reveal.resolveFrames(scope);
  final progress = revealProgress(frame, scope, reveal);
  final barProgress = stagger == null
      ? [for (var i = 0; i < categories.length; i++) progress]
      : staggeredRevealProgress(
          elapsed: elapsed,
          offsets: staggerOffsetFrames(
            stagger: stagger,
            childCount: categories.length,
            scope: scope,
          ),
          perSegmentFrames: revealFrames,
        );
  return BarChartPainter(
    tokens: tokens,
    progress: progress,
    categories: categories,
    values: values,
    barProgress: barProgress,
    colors: [for (var i = 0; i < categories.length; i++) tokens.palette.colorAt(i)],
  );
}

/// The painter behind `Chart.bar`: one rect per category, each grown from the
/// value baseline by `value x ease(segmentProgress)`.
///
/// It is an internal type (not exported by the barrel; authors call
/// `Chart.bar`). It holds size-independent data — the [categories], their
/// [values], one staggered [barProgress] each, and resolved [colors] — and
/// builds the pixel scales from the paint `size` so it draws correctly at any
/// layout size. [barRectsFor] exposes the resolved geometry so the growth is
/// unit-tested without a pixel readback.
final class BarChartPainter extends ChartPainter {
  /// Creates a bar painter; [plotRect] is unused (the painter derives the plot
  /// from the paint size) and defaults to [Rect.zero].
  BarChartPainter({
    required super.tokens,
    required super.progress,
    required this.categories,
    required this.values,
    required this.barProgress,
    required this.colors,
    this.ease = Ease.out,
  }) : super(plotRect: Rect.zero);

  /// The ordered category keys, in draw order.
  final List<String> categories;

  /// Each category's value, the height a bar grows toward, in category order.
  final List<num> values;

  /// One reveal progress in `[0, 1]` per category, already staggered.
  final List<double> barProgress;

  /// One fill color per category, already resolved from the palette / overrides.
  final List<Color> colors;

  /// The curve each bar's growth follows; [Ease.out] settles softly by default.
  final Curve ease;

  /// The categorical x scale across [size]'s plot rect.
  CategoryScale categoryScale(Size size) {
    final plot = ChartPainter.computePlotRect(size, chartGutters);
    return CategoryScale(
      categories: categories,
      pixelMin: plot.left,
      pixelMax: plot.right,
      padding: _barPadding,
    );
  }

  /// The value y scale (an upward axis) across [size]'s plot rect.
  LinearScale valueScale(Size size) {
    final plot = ChartPainter.computePlotRect(size, chartGutters);
    return LinearScale.niceBounds(
      min: 0,
      max: values.fold<num>(0, (m, v) => v > m ? v : m),
      pixelMin: plot.bottom,
      pixelMax: plot.top,
    );
  }

  /// The resolved bar rects at [size] and the current per-bar progress, in
  /// category order.
  ///
  /// Each rect spans its band's padded edges and rises from the value
  /// [LinearScale.baselinePixel] to `value.toPixel(datum x ease(progress))`, so
  /// a progress of `0` yields a zero-height rect at the baseline.
  List<Rect> barRectsFor(Size size) {
    final category = categoryScale(size);
    final value = valueScale(size);
    return [
      for (var i = 0; i < categories.length; i++) _rectFor(i, category, value),
    ];
  }

  Rect _rectFor(int index, CategoryScale category, LinearScale value) {
    final key = categories[index];
    final left = category.leftEdgeOf(key)!;
    final right = category.rightEdgeOf(key)!;
    final grown = ease.transform(barProgress[index].clamp(0.0, 1.0));
    final top = value.toPixel(values[index] * grown);
    return Rect.fromLTRB(left, top, right, value.baselinePixel);
  }

  @override
  void paintChart(Canvas canvas, Size size) {
    final value = valueScale(size);
    final plot = ChartPainter.computePlotRect(size, chartGutters);
    drawAxes(canvas, valueScale: value, plot: plot, tickCount: 4, tokens: tokens);
    final rects = barRectsFor(size);
    final paint = Paint();
    for (var i = 0; i < rects.length; i++) {
      paint.color = colors[i];
      canvas.drawRect(rects[i], paint);
    }
  }

  @override
  bool shouldRepaint(covariant ChartPainter oldDelegate) =>
      oldDelegate is! BarChartPainter ||
      oldDelegate.progress != progress ||
      oldDelegate.tokens != tokens ||
      !listEquals(oldDelegate.barProgress, barProgress) ||
      !listEquals(oldDelegate.values, values) ||
      !listEquals(oldDelegate.categories, categories) ||
      !listEquals(oldDelegate.colors, colors);
}
