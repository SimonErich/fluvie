import 'package:flutter/widgets.dart';

import 'package:kitten_kit/src/theme/kitten_colors.dart';

/// Paints a friendly kitten face from pure [Path] and [Canvas] ops.
///
/// It is fully deterministic and needs no image asset, so it renders identically
/// on every platform and avoids image licensing. Colors are caller-supplied.
class KittenFacePainter extends CustomPainter {
  /// Creates a painter for a kitten face in [fur] with [ink] features and
  /// [innerEar] inner-ear and nose color.
  const KittenFacePainter({
    this.fur = KittenColors.tabby,
    this.ink = KittenColors.ink,
    this.innerEar = KittenColors.mitten,
  });

  /// The fur color of the head and ears.
  final Color fur;

  /// The color of the eyes and whiskers.
  final Color ink;

  /// The inner-ear and nose color.
  final Color innerEar;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final cx = w / 2;
    final cy = size.height * 0.58;
    final r = w * 0.33;
    final furPaint = Paint()..color = fur;
    final inkPaint = Paint()..color = ink;
    final earPaint = Paint()..color = innerEar;
    final stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.012
      ..strokeCap = StrokeCap.round;

    Path ear(double dir) => Path()
      ..moveTo(cx + dir * r * 0.80, cy - r * 0.50)
      ..lineTo(cx + dir * r * 0.34, cy - r * 1.92)
      ..lineTo(cx + dir * r * 0.04, cy - r * 0.66)
      ..close();
    canvas
      ..drawPath(ear(-1), furPaint)
      ..drawPath(ear(1), furPaint);

    Path innerEarPath(double dir) => Path()
      ..moveTo(cx + dir * r * 0.62, cy - r * 0.62)
      ..lineTo(cx + dir * r * 0.34, cy - r * 1.50)
      ..lineTo(cx + dir * r * 0.16, cy - r * 0.70)
      ..close();
    canvas
      ..drawPath(innerEarPath(-1), earPaint)
      ..drawPath(innerEarPath(1), earPaint)
      ..drawCircle(Offset(cx, cy), r, furPaint);

    final eyeDx = r * 0.42;
    final eyeY = cy - r * 0.06;
    Rect eye(double dir) => Rect.fromCenter(
      center: Offset(cx + dir * eyeDx, eyeY),
      width: r * 0.26,
      height: r * 0.40,
    );
    canvas
      ..drawOval(eye(-1), inkPaint)
      ..drawOval(eye(1), inkPaint);

    final nose = Path()
      ..moveTo(cx - r * 0.10, cy + r * 0.20)
      ..lineTo(cx + r * 0.10, cy + r * 0.20)
      ..lineTo(cx, cy + r * 0.34)
      ..close();
    canvas.drawPath(nose, earPaint);

    for (final dir in const <double>[-1, 1]) {
      for (final dy in const <double>[-0.05, 0.06]) {
        canvas.drawLine(
          Offset(cx + dir * r * 0.20, cy + r * 0.26 + r * dy),
          Offset(cx + dir * r * 1.02, cy + r * 0.14 + r * dy * 2.4),
          stroke,
        );
      }
    }
  }

  @override
  bool shouldRepaint(KittenFacePainter oldDelegate) =>
      oldDelegate.fur != fur || oldDelegate.ink != ink || oldDelegate.innerEar != innerEar;
}
