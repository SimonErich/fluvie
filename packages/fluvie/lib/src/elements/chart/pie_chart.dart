import 'dart:math' as math;
import 'dart:ui' show Canvas, Color, Offset, Paint, Path, PathFillType, Rect, Size;

import 'package:flutter/animation.dart' show Curve;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/chart/painter/chart_painter.dart';
import 'package:fluvie/src/elements/reveal/reveal_progress.dart';
import 'package:fluvie/src/theme/fluvie_tokens.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

/// The angle a pie / donut sweep begins at: 12 o'clock (`-pi/2` from the
/// canvas's 3 o'clock zero), so segments grow clockwise from the top.
const double _twelveOClock = -math.pi / 2;

/// The fraction of the smaller plot dimension a pie's outer radius fills, so a
/// thin gutter keeps the disc off the chart bounds.
const double _radiusFraction = 0.45;

/// Builds the [PieChartPainter] for `Chart.pie` / `Chart.donut` at [frame]
/// within [scope] — the data-transform layer that resolves the per-segment full
/// angles and the shared reveal progress, leaving pixel placement to the
/// painter.
///
/// Each segment's full angle is `2 pi x value / total`, so the segments sum to a
/// full turn at progress `1`. The whole disc sweeps angularly with
/// [revealProgress]; the painter scales each full angle by `ease(progress)`
/// when it draws. [innerRadius] is `0` for a pie and a fraction in `(0, 1)` for a
/// donut hole.
PieChartPainter buildPiePainter({
  required int frame,
  required TimeScopeData scope,
  required Map<String, num> data,
  required Time reveal,
  double innerRadius = 0,
  FluvieTokens tokens = const FluvieTokens.fallback(),
}) {
  final values = data.values.toList();
  final total = values.fold<num>(0, (sum, v) => sum + (v > 0 ? v : 0));
  final fullAngles = [
    for (final value in values) total <= 0 ? 0.0 : 2 * math.pi * (value > 0 ? value : 0) / total,
  ];
  return PieChartPainter(
    tokens: tokens,
    progress: revealProgress(frame, scope, reveal),
    fullAngles: fullAngles,
    innerRadius: innerRadius,
    colors: [for (var i = 0; i < values.length; i++) tokens.palette.colorAt(i)],
  );
}

/// The painter behind `Chart.pie` and `Chart.donut`: one arc segment per value,
/// each swept clockwise from 12 o'clock by `fullAngle x ease(progress)`.
///
/// It is an internal type (authors call `Chart.pie` / `Chart.donut`). The chart
/// resolves the size-independent full angles in `build`; the painter places the
/// pixels from the paint `size`. The donut hole is cut with an even-odd fill (a
/// `Path.combine`-free ring) so the draw stays capture-safe — no `saveLayer`.
/// [sweepAngles] and [segmentPath] expose the resolved geometry so the sweep and
/// the hole are unit-tested without a pixel readback.
final class PieChartPainter extends ChartPainter {
  /// Creates a pie / donut painter over the resolved [fullAngles].
  PieChartPainter({
    required super.tokens,
    required super.progress,
    required this.fullAngles,
    required this.colors,
    this.innerRadius = 0,
    this.ease = Ease.out,
  }) : super(plotRect: Rect.zero);

  /// Each segment's full (progress `1`) sweep angle, in value order.
  final List<double> fullAngles;

  /// One fill color per segment, already resolved from the palette / overrides.
  final List<Color> colors;

  /// The donut hole radius as a fraction of the outer radius, in `[0, 1)`; `0`
  /// for a pie (no hole).
  final double innerRadius;

  /// The curve the angular sweep follows; [Ease.out] settles softly by default.
  final Curve ease;

  /// The canvas start angle every segment sweeps from: 12 o'clock.
  double get startAngle => _twelveOClock;

  /// The plot center at [size].
  Offset center(Size size) => Offset(size.width / 2, size.height / 2);

  /// The outer disc radius at [size] (a fraction of the smaller dimension).
  double outerRadius(Size size) => math.min(size.width, size.height) * _radiusFraction;

  /// The donut hole radius in pixels at [size] (`0` for a pie).
  double holeRadius(Size size) => outerRadius(size) * innerRadius;

  /// Each segment's swept angle at the current [progress]: its full angle times
  /// `ease(progress)`, in value order.
  List<double> get sweepAngles {
    final grown = ease.transform(progress.clamp(0.0, 1.0));
    return [for (final full in fullAngles) full * grown];
  }

  /// The closed fill path for segment [index] at [size] and the current sweep.
  ///
  /// A pie segment is a wedge (center to the swept arc); a donut segment is the
  /// ring slice between [holeRadius] and [outerRadius], filled even-odd so the
  /// hole stays empty without a `saveLayer` mask.
  Path segmentPath(Size size, int index) {
    final start = _segmentStart(index);
    final sweep = sweepAngles[index];
    return innerRadius <= 0 ? _wedgePath(size, start, sweep) : _ringPath(size, start, sweep);
  }

  double _segmentStart(int index) {
    final grown = ease.transform(progress.clamp(0.0, 1.0));
    var start = _twelveOClock;
    for (var i = 0; i < index; i++) {
      start += fullAngles[i] * grown;
    }
    return start;
  }

  Path _wedgePath(Size size, double start, double sweep) {
    final c = center(size);
    final outer = outerRadius(size);
    final rect = Rect.fromCircle(center: c, radius: outer);
    return Path()
      ..moveTo(c.dx, c.dy)
      ..arcTo(rect, start, sweep, false)
      ..close();
  }

  /// An annular sector (a true ring slice) between [holeRadius] and
  /// [outerRadius]: the inner arc start, out to the outer arc forward, then the
  /// inner arc back, closed.
  ///
  /// The path never reaches the disc center, so the hole stays empty with a
  /// plain even-odd fill and no `saveLayer`.
  Path _ringPath(Size size, double start, double sweep) {
    final c = center(size);
    final hole = holeRadius(size);
    final outerRect = Rect.fromCircle(center: c, radius: outerRadius(size));
    final innerRect = Rect.fromCircle(center: c, radius: hole);
    final startInner = Offset(c.dx + hole * math.cos(start), c.dy + hole * math.sin(start));
    return Path()
      ..moveTo(startInner.dx, startInner.dy)
      ..arcTo(outerRect, start, sweep, true)
      ..arcTo(innerRect, start + sweep, -sweep, false)
      ..close()
      ..fillType = PathFillType.evenOdd;
  }

  @override
  void paintChart(Canvas canvas, Size size) {
    final paint = Paint();
    for (var i = 0; i < fullAngles.length; i++) {
      if (sweepAngles[i] <= 0) continue;
      paint.color = colors[i];
      canvas.drawPath(segmentPath(size, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant ChartPainter oldDelegate) =>
      oldDelegate is! PieChartPainter ||
      oldDelegate.progress != progress ||
      oldDelegate.tokens != tokens ||
      oldDelegate.innerRadius != innerRadius ||
      !listEquals(oldDelegate.fullAngles, fullAngles);
}
