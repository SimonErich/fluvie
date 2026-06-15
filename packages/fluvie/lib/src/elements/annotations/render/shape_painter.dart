import 'dart:ui' show Canvas, Color, Offset, Paint, PaintingStyle, Path, Rect, Size, StrokeCap;

import 'package:flutter/rendering.dart' show CustomPainter;

/// Which primitive a [ShapePainter] draws.
enum ShapeKind {
  /// A straight stroked line between two points.
  line,

  /// A stroked rectangle.
  rect,

  /// A stroked circle.
  circle,

  /// An arbitrary stroked [Path].
  path,
}

/// Paints one annotation primitive — a line, rect, circle, or path — stroked in
/// [color], drawn on left-to-right over a `[0, 1]` [progress].
///
/// The painter is a pure function of its geometry, [color], [strokeWidth], and
/// [progress], so the same frame renders byte-identically. Capture-safe:
/// it strokes with plain `Paint`s, never a `saveLayer` or `BackdropFilter`. The
/// draw-on trims each primitive's outline to [progress] using `PathMetric`, so
/// the stroke grows along its own length rather than fading.
final class ShapePainter extends CustomPainter {
  /// Creates a painter over the resolved [kind] geometry stroked in [color].
  ShapePainter({
    required this.kind,
    required this.color,
    required this.progress,
    required this.strokeWidth,
    this.from,
    this.to,
    this.rect,
    this.center,
    this.radius,
    this.path,
  });

  /// Which primitive this draws.
  final ShapeKind kind;

  /// The stroke color (from `context.fluvie` or an explicit override).
  final Color color;

  /// The draw-on progress in `[0, 1]`; `1` is fully drawn.
  final double progress;

  /// The stroke width in logical pixels.
  final double strokeWidth;

  /// The start point of a [ShapeKind.line].
  final Offset? from;

  /// The end point of a [ShapeKind.line].
  final Offset? to;

  /// The bounds of a [ShapeKind.rect].
  final Rect? rect;

  /// The center of a [ShapeKind.circle].
  final Offset? center;

  /// The radius of a [ShapeKind.circle].
  final double? radius;

  /// The outline of a [ShapeKind.path].
  final Path? path;

  /// The full outline of this shape, before any draw-on trim — the geometry
  /// tests assert against this so they never read pixels.
  Path get outline {
    switch (kind) {
      case ShapeKind.line:
        return Path()
          ..moveTo(from!.dx, from!.dy)
          ..lineTo(to!.dx, to!.dy);
      case ShapeKind.rect:
        return Path()..addRect(rect!);
      case ShapeKind.circle:
        return Path()..addOval(Rect.fromCircle(center: center!, radius: radius!));
      case ShapeKind.path:
        return path!;
    }
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
  bool shouldRepaint(covariant ShapePainter oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.color != color ||
      oldDelegate.progress != progress ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.from != from ||
      oldDelegate.to != to ||
      oldDelegate.rect != rect ||
      oldDelegate.center != center ||
      oldDelegate.radius != radius ||
      oldDelegate.path != path;
}
