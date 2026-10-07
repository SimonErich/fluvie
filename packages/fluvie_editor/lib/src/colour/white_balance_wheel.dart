import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';

/// White-balance wheel: horizontal warmth, vertical green/magenta tint.
/// Numeric alternatives live beside it in the grade's parameter grid.
final class WhiteBalanceWheel extends StatefulWidget {
  /// Commits both channels together on release.
  const WhiteBalanceWheel({
    required this.temperature,
    required this.tint,
    required this.onChanged,
    super.key,
  });

  /// Warm/cool balance in the range -1 to 1.
  final double temperature;

  /// Magenta/green balance in the range -1 to 1.
  final double tint;

  /// Commits both channels together after a gesture.
  final void Function(double temperature, double tint) onChanged;
  @override
  State<WhiteBalanceWheel> createState() => _WhiteBalanceWheelState();
}

final class _WhiteBalanceWheelState extends State<WhiteBalanceWheel> {
  Offset? _drag;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const OiLabel.small('White balance · warm / cool · magenta / green'),
      const SizedBox(height: 6),
      SizedBox(
        width: 132,
        height: 132,
        child: Semantics(
          label: 'White balance wheel. Use temperature and tint fields for keyboard editing.',
          child: GestureDetector(
            onPanStart: (_) => setState(() => _drag = Offset(widget.temperature, widget.tint)),
            onPanUpdate: (event) => setState(
              () => _drag = Offset(
                ((event.localPosition.dx - 66) / 60).clamp(-1, 1),
                ((66 - event.localPosition.dy) / 60).clamp(-1, 1),
              ),
            ),
            onPanCancel: () => setState(() => _drag = null),
            onPanEnd: (_) {
              final point = _drag;
              setState(() => _drag = null);
              if (point != null) widget.onChanged(point.dx, point.dy);
            },
            child: CustomPaint(
              painter: _WheelPainter(
                _drag ?? Offset(widget.temperature, widget.tint),
                context.colors.text,
              ),
            ),
          ),
        ),
      ),
      OiButton.ghost(label: 'Reset white balance', onTap: () => widget.onChanged(0, 0)),
    ],
  );
}

final class _WheelPainter extends CustomPainter {
  const _WheelPainter(this.point, this.foreground);
  final Offset point;
  final Color foreground;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 6;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            Color(0xFFE99B54),
            Color(0xFF66AA77),
            Color(0xFF649BDD),
            Color(0xFFCC75BE),
            Color(0xFFE99B54),
          ],
        ).createShader(rect),
    );
    // Separate shader paints document the wheel’s two composited layers.
    // ignore: cascade_invocations
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFE4E4E4), Color(0x00E4E4E4)],
        ).createShader(rect),
    );
    final cursor = center + Offset(point.dx * radius, -point.dy * radius);
    canvas.drawCircle(
      cursor,
      4,
      Paint()
        ..color = foreground
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_WheelPainter oldDelegate) =>
      oldDelegate.point != point || oldDelegate.foreground != foreground;
}
