part of 'colour_scopes.dart';

final class _ScopePainter extends CustomPainter {
  const _ScopePainter(this.data, this.mode, this.color, this.grid);
  final ScopeData data;
  final String mode;
  final Color color;
  final Color grid;
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i <= 4; i++) {
      canvas.drawLine(
        Offset(0, size.height * i / 4),
        Offset(size.width, size.height * i / 4),
        Paint()..color = grid,
      );
    }
    if (mode == 'Histogram') {
      const colors = [Color(0xFFFF6666), Color(0xFF66DD88), Color(0xFF66AAFF)];
      final channels = [data.red, data.green, data.blue];
      var max = 1;
      for (final channel in channels) {
        for (final count in channel) {
          if (count > max) max = count;
        }
      }
      for (var c = 0; c < 3; c++) {
        final path = Path();
        for (var i = 0; i < 256; i++) {
          final x = i / 255 * size.width;
          final y = size.height * (1 - channels[c][i] / max);
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        canvas.drawPath(
          path,
          Paint()
            ..color = colors[c]
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
      return;
    }
    final bins = mode == 'Waveform' ? data.waveform : data.vectorscope;
    var max = 1;
    for (final count in bins) {
      if (count > max) max = count;
    }
    for (var i = 0; i < bins.length; i++) {
      if (bins[i] == 0) continue;
      canvas.drawRect(
        Rect.fromLTWH(
          i % 64 * size.width / 64,
          (63 - i ~/ 64) * size.height / 64,
          size.width / 64 + 0.2,
          size.height / 64 + 0.2,
        ),
        Paint()..color = color.withValues(alpha: (0.2 + 0.8 * bins[i] / max).clamp(0, 1)),
      );
    }
  }

  @override
  bool shouldRepaint(_ScopePainter oldDelegate) =>
      data != oldDelegate.data || mode != oldDelegate.mode || color != oldDelegate.color;
}
