import 'dart:ui' show Canvas, Color, Offset, Paint, PaintingStyle, Path, Size, StrokeCap;

import 'package:flutter/rendering.dart' show CustomPainter;

/// Paints an arrow: a stroked shaft from [from] toward [to] with a filled
/// triangular head at the tip.
///
/// The shaft draws on left-to-right over a `[0, 1]` [progress]: it runs from
/// [from] to [headBase] (the point set back from the tip by [headLength]),
/// clipped to [progress], so the line grows toward the head. The head only
/// appears once the shaft has fully drawn ([headVisible]), so the arrow reads as
/// arriving rather than blinking in. The geometry ([headBase], [shaftEnd]) is
/// exposed so tests assert against it without reading pixels.
///
/// A pure function of its geometry, [color], [strokeWidth], [headLength], and
/// [progress], so identical frames render byte-identically. Capture-safe:
/// a plain stroke and a plain fill, no `saveLayer` or `BackdropFilter`.
final class ArrowPainter extends CustomPainter {
  /// Creates a painter over the shaft from [from] to [to] in [color].
  ArrowPainter({
    required this.from,
    required this.to,
    required this.color,
    required this.progress,
    required this.strokeWidth,
    required this.headLength,
  });

  /// The tail of the arrow (the shaft origin).
  final Offset from;

  /// The tip of the arrow (where the head points).
  final Offset to;

  /// The arrow color (from `context.fluvie` or an explicit override).
  final Color color;

  /// The draw-on progress in `[0, 1]`; the head appears at `1`.
  final double progress;

  /// The shaft stroke width in logical pixels.
  final double strokeWidth;

  /// The length of the triangular head along the shaft, in logical pixels.
  final double headLength;

  /// The direction from [from] to [to] as a unit vector, or `(1, 0)` for a
  /// zero-length arrow (so the geometry never divides by zero).
  Offset get _direction {
    final delta = to - from;
    final length = delta.distance;
    return length == 0 ? const Offset(1, 0) : delta / length;
  }

  /// The point where the shaft ends and the head begins — the tip set back along
  /// the shaft by [headLength] (clamped so it never crosses [from]).
  Offset get headBase {
    final length = (to - from).distance;
    final back = headLength.clamp(0.0, length);
    return to - _direction * back;
  }

  /// The current end of the drawn-on shaft: [from] plus [progress] of the way to
  /// [headBase].
  Offset get shaftEnd => Offset.lerp(from, headBase, progress.clamp(0.0, 1.0))!;

  /// Whether the head is drawn yet — only once the shaft has fully drawn on.
  bool get headVisible => progress >= 1;

  @override
  void paint(Canvas canvas, Size size) {
    final shaftPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from, shaftEnd, shaftPaint);
    if (headVisible) _paintHead(canvas);
  }

  /// Paints the filled triangular head at the tip, splayed [headLength] back and
  /// out along the shaft normal.
  void _paintHead(Canvas canvas) {
    final dir = _direction;
    final normal = Offset(-dir.dy, dir.dx);
    final halfWidth = headLength * 0.5;
    final base = headBase;
    final left = base + normal * halfWidth;
    final right = base - normal * halfWidth;
    final head = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(head, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant ArrowPainter oldDelegate) =>
      oldDelegate.from != from ||
      oldDelegate.to != to ||
      oldDelegate.color != color ||
      oldDelegate.progress != progress ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.headLength != headLength;
}
