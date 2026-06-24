import 'package:flutter/widgets.dart';

import 'package:kitten_kit/src/theme/kitten_colors.dart';

/// Paints a single kitten paw print (one pad and four toe beans) from pure
/// [Canvas] ops, deterministic and asset-free. Used as confetti and accents.
class PawPrintPainter extends CustomPainter {
  /// Creates a paw-print painter filled with [color].
  const PawPrintPainter({this.color = KittenColors.mitten});

  /// The fill color of the pad and toe beans.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..color = color;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(w * 0.5, h * 0.68), width: w * 0.54, height: h * 0.44),
        Radius.circular(w * 0.24),
      ),
      paint,
    );

    const toes = <Offset>[
      Offset(0.24, 0.36),
      Offset(0.42, 0.20),
      Offset(0.60, 0.20),
      Offset(0.78, 0.36),
    ];
    for (final t in toes) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(w * t.dx, h * t.dy), width: w * 0.19, height: h * 0.24),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(PawPrintPainter oldDelegate) => oldDelegate.color != color;
}
