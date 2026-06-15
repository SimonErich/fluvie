import 'package:flutter/rendering.dart' show Canvas, Offset, Paint, PaintingStyle, Rect;
import 'package:fluvie/src/elements/chart/scale/chart_scale.dart';
import 'package:fluvie/src/theme/fluvie_tokens.dart';
import 'package:meta/meta.dart' show immutable;

/// One horizontal gridline span at a value tick.
///
/// The line runs from [left] to [right] at vertical pixel [y]; a chart draws
/// these behind the plot to mark value-axis ticks. It is the pure output of
/// [axisGridlines], so the layout is unit-tested without a canvas.
@immutable
final class AxisGridline {
  /// Creates a gridline from [left] to [right] at [y].
  const AxisGridline({required this.left, required this.right, required this.y});

  /// The line's start x pixel (the plot's left edge).
  final double left;

  /// The line's end x pixel (the plot's right edge).
  final double right;

  /// The line's vertical pixel, where the value tick sits on the y axis.
  final double y;

  @override
  bool operator ==(Object other) =>
      other is AxisGridline && other.left == left && other.right == right && other.y == y;

  @override
  int get hashCode => Object.hash(AxisGridline, left, right, y);
}

/// One horizontal gridline per value tick of [valueScale] across [plot].
///
/// Each tick value maps through [valueScale] to a pixel `y`, and the line spans
/// the plot's horizontal extent. [tickCount] is the number of intervals (so the
/// result has `tickCount + 1` lines); a non-positive count yields the two
/// domain endpoints. Pure math — identical inputs always return identical
/// lines.
List<AxisGridline> axisGridlines({
  required LinearScale valueScale,
  required Rect plot,
  required int tickCount,
}) => [
  for (final tick in valueScale.ticks(tickCount))
    AxisGridline(left: plot.left, right: plot.right, y: valueScale.toPixel(tick)),
];

/// Draws the value-axis gridlines and the plot baseline using [tokens].
///
/// Only `drawLine` / `drawRect` style primitives are used (no `saveLayer`), so
/// the draw is capture-safe and deterministic. The gridlines use
/// [FluvieTokens.gridColor]; the baseline (the bottom of the plot) uses
/// [FluvieTokens.axisColor].
void drawAxes(
  Canvas canvas, {
  required LinearScale valueScale,
  required Rect plot,
  required int tickCount,
  required FluvieTokens tokens,
}) {
  final grid = Paint()
    ..color = tokens.gridColor
    ..strokeWidth = 1
    ..style = PaintingStyle.stroke;
  for (final line in axisGridlines(valueScale: valueScale, plot: plot, tickCount: tickCount)) {
    canvas.drawLine(Offset(line.left, line.y), Offset(line.right, line.y), grid);
  }
  final axis = Paint()
    ..color = tokens.axisColor
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke;
  canvas.drawLine(plot.bottomLeft, plot.bottomRight, axis);
}
