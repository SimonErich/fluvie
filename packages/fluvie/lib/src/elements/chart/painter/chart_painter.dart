import 'dart:math' as math;

import 'package:flutter/rendering.dart' show Canvas, CustomPainter, Rect, Size;
import 'package:fluvie/src/theme/fluvie_tokens.dart';
import 'package:meta/meta.dart' show immutable, nonVirtual, protected;

/// The pixel insets between a chart's bounds and its plot rect.
///
/// Gutters reserve room for the value-axis labels (on the [left]), the
/// category-axis labels and baseline (on the [bottom]), and any top / right
/// breathing room. They are pure data so the plot rect is a deterministic
/// function of the chart size.
@immutable
final class ChartGutters {
  /// Creates gutters with the given pixel insets (all default to `0`).
  const ChartGutters({this.left = 0, this.top = 0, this.right = 0, this.bottom = 0});

  /// No gutters: the plot fills the whole chart bounds.
  static const ChartGutters none = ChartGutters();

  /// The inset reserved on the left (value-axis labels).
  final double left;

  /// The inset reserved on the top.
  final double top;

  /// The inset reserved on the right.
  final double right;

  /// The inset reserved on the bottom (category-axis labels / baseline).
  final double bottom;

  @override
  bool operator ==(Object other) =>
      other is ChartGutters &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(ChartGutters, left, top, right, bottom);
}

/// The base of every chart painter: it holds the resolved geometry the chart
/// computed and draws nothing but the resolved data.
///
/// A `Chart` widget computes its scales (data transforms) in `build` and hands
/// this painter a [plotRect], the [tokens] to color with, and
/// the reveal [progress]. Subclasses override [paintChart] to draw their bars /
/// lines / arcs into the plot rect; they never touch raw data. [shouldRepaint]
/// is true exactly when the [progress], [plotRect], or [tokens] differ
/// (frame-correct — never time-based), so identical frames never repaint.
abstract base class ChartPainter extends CustomPainter {
  /// Creates a painter over the resolved [plotRect], [tokens], and reveal
  /// [progress].
  const ChartPainter({required this.plotRect, required this.tokens, required this.progress});

  /// The rect the chart draws its data into (bounds minus gutters).
  final Rect plotRect;

  /// The design tokens this chart colors with.
  final FluvieTokens tokens;

  /// The reveal progress in `[0, 1]` driving the grow / sweep / pop animation.
  final double progress;

  /// The plot rect for a chart of [size] after insetting by [gutters].
  ///
  /// Pure geometry, clamped so an over-large gutter never produces a negative
  /// rect (the right / bottom never cross the left / top).
  static Rect computePlotRect(Size size, ChartGutters gutters) {
    final left = gutters.left;
    final top = gutters.top;
    final right = math.max(left, size.width - gutters.right);
    final bottom = math.max(top, size.height - gutters.bottom);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// Draws the chart's data into [size]; the base delegates [paint] here after
  /// subclasses (and shared chrome) have what they need.
  @protected
  void paintChart(Canvas canvas, Size size);

  @override
  @nonVirtual
  void paint(Canvas canvas, Size size) => paintChart(canvas, size);

  @override
  bool shouldRepaint(covariant ChartPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.plotRect != plotRect ||
      oldDelegate.tokens != tokens;
}
