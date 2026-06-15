import 'dart:ui' show Canvas, Color, Offset, Paint, PaintingStyle, Path, Size, StrokeCap;

import 'package:flutter/rendering.dart' show CustomPainter;

/// Paints a connector linking two explicit points: a straight line, or an
/// [corner]-bent elbow when [corner] is non-null.
///
/// The connector draws on over a `[0, 1]` [progress] by trimming its outline to
/// that fraction of its length (`PathMetric`), so it grows from [from] toward
/// [to]. A pure function of its geometry, [color], [strokeWidth], and
/// [progress], so identical frames render byte-identically. Capture-safe:
/// a plain stroke, no `saveLayer` or `BackdropFilter`.
final class ConnectorPainter extends CustomPainter {
  /// Creates a painter linking [from] to [to] in [color], bending through
  /// [corner] when non-null.
  ConnectorPainter({
    required this.from,
    required this.to,
    required this.color,
    required this.progress,
    required this.strokeWidth,
    this.corner,
  });

  /// The first linked point.
  final Offset from;

  /// The second linked point.
  final Offset to;

  /// The corner an elbow bends through, or `null` for a straight connector.
  final Offset? corner;

  /// The stroke color (from `context.fluvie` or an explicit override).
  final Color color;

  /// The draw-on progress in `[0, 1]`; `1` is fully drawn.
  final double progress;

  /// The stroke width in logical pixels.
  final double strokeWidth;

  /// The full outline before any draw-on trim — `from` to `to`, optionally via
  /// [corner]. Exposed so geometry tests share the painter's exact path.
  Path get outline {
    final path = Path()..moveTo(from.dx, from.dy);
    final via = corner;
    if (via != null) path.lineTo(via.dx, via.dy);
    return path..lineTo(to.dx, to.dy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(trimmedTo(progress), paint);
  }

  /// The [outline] trimmed to the first [fraction] of its length — the draw-on
  /// geometry, exposed so tests share the painter's exact math.
  Path trimmedTo(double fraction) {
    final full = outline;
    if (fraction >= 1) return full;
    if (fraction <= 0) return Path();
    final trimmed = Path();
    for (final metric in full.computeMetrics()) {
      trimmed.addPath(metric.extractPath(0, metric.length * fraction), Offset.zero);
    }
    return trimmed;
  }

  @override
  bool shouldRepaint(covariant ConnectorPainter oldDelegate) =>
      oldDelegate.from != from ||
      oldDelegate.to != to ||
      oldDelegate.corner != corner ||
      oldDelegate.color != color ||
      oldDelegate.progress != progress ||
      oldDelegate.strokeWidth != strokeWidth;
}
