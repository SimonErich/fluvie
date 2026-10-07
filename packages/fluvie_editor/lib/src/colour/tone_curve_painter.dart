part of 'tone_curve_editor.dart';

final class _CurvePainter extends CustomPainter {
  const _CurvePainter(this.points, this.selected, this.color, this.grid, this.background);
  final List<Offset> points;
  final int selected;
  final Color color;
  final Color grid;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    Offset screen(Offset p) => Offset(p.dx * size.width, (1 - p.dy) * size.height);
    for (var i = 0; i <= 4; i++) {
      final t = i / 4;
      canvas
        ..drawLine(screen(Offset(t, 0)), screen(Offset(t, 1)), Paint()..color = grid)
        ..drawLine(screen(Offset(0, t)), screen(Offset(1, t)), Paint()..color = grid);
    }
    final curve = ToneCurve.fromPoints([for (final p in points) (p.dx, p.dy)]);
    final path = Path();
    for (var i = 0; i <= 128; i++) {
      final p = screen(Offset(i / 128, curve.at(i / 128)));
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
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(screen(points[i]), i == selected ? 5 : 3, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_CurvePainter oldDelegate) => true;
}
