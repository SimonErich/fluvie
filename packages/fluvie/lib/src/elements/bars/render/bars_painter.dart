import 'dart:ui' show Canvas, Color, Paint, RRect, Radius, Rect, Size;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/rendering.dart' show CustomPainter;

/// Paints the spectrum [heights] as upright [color] bars rising from the bottom
/// of the canvas.
///
/// Each entry of [heights] is a `[0, 1]` fraction of the canvas height; the
/// painter spreads `heights.length` evenly-spaced bars across the width with a
/// fixed inter-bar gap and clamps each height into range, so an over-driven gain
/// never paints past the top. It is value-comparable by [heights] and [color],
/// so identical frames never repaint — the frame-cache contract.
final class BarsPainter extends CustomPainter {
  /// Creates a painter over the per-bar [heights] (`[0, 1]`) in [color].
  const BarsPainter({required this.heights, required this.color});

  /// The fraction of the canvas height each bar fills, left to right.
  final List<double> heights;

  /// The fill color every bar paints in (from `context.fluvie`).
  final Color color;

  /// The fraction of each bar slot left empty as the inter-bar gap.
  static const double _gap = 0.25;

  @override
  void paint(Canvas canvas, Size size) {
    if (heights.isEmpty) return;
    final slot = size.width / heights.length;
    final barWidth = slot * (1 - _gap);
    final paint = Paint()..color = color;
    for (var i = 0; i < heights.length; i++) {
      final fraction = heights[i].clamp(0.0, 1.0);
      final barHeight = fraction * size.height;
      final left = i * slot + (slot - barWidth) / 2;
      final rect = Rect.fromLTWH(left, size.height - barHeight, barWidth, barHeight);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(barWidth / 4)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant BarsPainter oldDelegate) =>
      oldDelegate.color != color || !listEquals(oldDelegate.heights, heights);
}
