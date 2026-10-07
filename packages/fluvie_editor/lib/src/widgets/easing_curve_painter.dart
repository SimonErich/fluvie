part of 'easing_curve_editor.dart';

final class _EasingPainter extends CustomPainter {
  const _EasingPainter(this.curve, this.points, this.color, this.grid);
  final Curve curve;
  final List<double> points;
  final Color color;
  final Color grid;
  @override
  void paint(Canvas canvas, Size size) {
    Offset point(double x, double y) => Offset(x * size.width, (1 - y) * size.height);
    final gridPaint = Paint()..color = grid;
    for (var i = 0; i <= 4; i++) {
      final t = i / 4;
      canvas
        ..drawLine(point(t, 0), point(t, 1), gridPaint)
        ..drawLine(point(0, t), point(1, t), gridPaint);
    }
    final path = Path();
    for (var i = 0; i <= 100; i++) {
      final p = point(i / 100, curve.transform(i / 100));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (var handle = 0; handle < 2; handle++) {
      final p = point(points[handle * 2], points[handle * 2 + 1]);
      canvas
        ..drawLine(point(handle.toDouble(), handle.toDouble()), p, gridPaint)
        ..drawCircle(p, 5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_EasingPainter oldDelegate) => true;
}
