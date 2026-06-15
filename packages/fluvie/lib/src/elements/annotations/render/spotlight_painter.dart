import 'dart:ui' show Canvas, Color, Offset, Paint, Path, PathFillType, RRect, Radius, Rect, Size;

import 'package:flutter/rendering.dart' show CustomPainter;

/// Paints the spotlight dim: a full-canvas [dimColor] fill with a rounded hole
/// punched out over [region], grown by the `[0, 1]` [reveal].
///
/// The dim is a single even-odd `Path` (the canvas rect plus the region rect),
/// so the overlap subtracts — there is no `saveLayer` and no `BackdropFilter`,
/// which keeps it capture-safe. The hole grows from nothing to the full
/// [region] as [reveal] runs `0 -> 1`, so the spotlight opens rather than
/// blinking on. A pure function of its inputs, so identical frames render
/// byte-identically.
final class SpotlightPainter extends CustomPainter {
  /// Creates a painter dimming everything but [region], with the hole grown by
  /// [reveal].
  const SpotlightPainter({
    required this.region,
    required this.reveal,
    required this.dimColor,
    this.cornerRadius = 12,
  });

  /// The lit rect: the area kept clear of the dim.
  final Rect region;

  /// The hole-grow progress in `[0, 1]`; `0` dims the whole canvas, `1` opens
  /// the full [region].
  final double reveal;

  /// The color the dimmed area is filled with (typically translucent black).
  final Color dimColor;

  /// The corner radius of the lit hole.
  final double cornerRadius;

  /// Whether the dim is drawn with the even-odd fill rule — always true, exposed
  /// so the capture-safe test asserts the fill never uses `saveLayer`.
  bool get usesEvenOdd => true;

  /// The lit hole at this frame: [region] scaled about its center by [reveal].
  Rect get hole {
    final t = reveal.clamp(0.0, 1.0);
    final center = region.center;
    final halfW = region.width / 2 * t;
    final halfH = region.height / 2 * t;
    return Rect.fromLTRB(
      center.dx - halfW,
      center.dy - halfH,
      center.dx + halfW,
      center.dy + halfH,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final dim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(hole, Radius.circular(cornerRadius)));
    canvas.drawPath(dim, Paint()..color = dimColor);
  }

  @override
  bool shouldRepaint(covariant SpotlightPainter oldDelegate) =>
      oldDelegate.region != region ||
      oldDelegate.reveal != reveal ||
      oldDelegate.dimColor != dimColor ||
      oldDelegate.cornerRadius != cornerRadius;
}
