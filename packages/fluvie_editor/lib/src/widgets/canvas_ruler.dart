import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/widgets/canvas_viewport.dart';
import 'package:obers_ui/obers_ui.dart' show OiBuildContextThemeExt;

// obers_ui upstream candidate: a zoom-aware ruler strip for any canvas
// editor sharing the CanvasViewportController camera.

/// One ruler strip: the top one ([Axis.horizontal], measuring x) or the
/// left one ([Axis.vertical], measuring y), marked in canvas units and
/// scaled live by the camera's zoom.
final class CanvasRuler extends StatelessWidget {
  /// A ruler along [axis] under [viewport]'s camera.
  const CanvasRuler({required this.axis, required this.viewport, super.key});

  /// The on-screen thickness of a ruler strip in logical pixels.
  static const double thickness = 24;

  /// Which ruler this is: horizontal sits on top, vertical on the left.
  final Axis axis;

  /// The camera mapping canvas to viewport pixels.
  final CanvasViewportController viewport;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListenableBuilder(
      listenable: viewport,
      builder: (context, _) => CustomPaint(
        size: axis == Axis.horizontal
            ? const Size(double.infinity, thickness)
            : const Size(thickness, double.infinity),
        painter: _RulerPainter(
          axis: axis,
          scale: viewport.scale,
          offset: axis == Axis.horizontal ? viewport.offset.dx : viewport.offset.dy,
          background: colors.surface,
          tick: colors.textSubtle,
          labelStyle: context.textTheme.caption.copyWith(
            color: colors.textSubtle,
            fontSize: 9,
            height: 1,
          ),
        ),
      ),
    );
  }
}

final class _RulerPainter extends CustomPainter {
  const _RulerPainter({
    required this.axis,
    required this.scale,
    required this.offset,
    required this.background,
    required this.tick,
    required this.labelStyle,
  });

  final Axis axis;
  final double scale;
  final double offset;
  final Color background;
  final Color tick;
  final TextStyle labelStyle;

  /// The canvas-unit distance between labeled ticks: the smallest "nice"
  /// step that keeps labels at least ~48 screen pixels apart.
  static double _stepFor(double scale) {
    const steps = [1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0, 200.0, 500.0, 1000.0, 2000.0, 5000.0];
    for (final step in steps) {
      if (step * scale >= 48) return step;
    }
    return 10000;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final along = axis == Axis.horizontal ? size.width : size.height;
    final paint = Paint()
      ..color = tick.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    final step = _stepFor(scale);
    final minor = step / 5;
    final drawMinor = minor * scale >= 8;
    var value = (-offset / scale / minor).floorToDouble() * minor;
    for (; value * scale + offset <= along; value += minor) {
      final position = value * scale + offset;
      if (position < 0) continue;
      final major = (value / step - (value / step).roundToDouble()).abs() < 1e-6;
      if (!major && !drawMinor) continue;
      _tick(canvas, position, major: major, paint: paint);
      if (major) _label(canvas, position, value);
    }
  }

  void _tick(Canvas canvas, double position, {required bool major, required Paint paint}) {
    final length = major ? 7.0 : 4.0;
    if (axis == Axis.horizontal) {
      canvas.drawLine(
        Offset(position, CanvasRuler.thickness - length),
        Offset(position, CanvasRuler.thickness),
        paint,
      );
    } else {
      canvas.drawLine(
        Offset(CanvasRuler.thickness - length, position),
        Offset(CanvasRuler.thickness, position),
        paint,
      );
    }
  }

  void _label(Canvas canvas, double position, double value) {
    final painter = TextPainter(
      text: TextSpan(text: '${value.round()}', style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    if (axis == Axis.horizontal) {
      painter.paint(canvas, Offset(position + 3, 2));
    } else {
      // The left ruler's labels read bottom-to-top, the Figma way.
      canvas
        ..save()
        ..translate(2, position - 3)
        ..rotate(-math.pi / 2);
      painter.paint(canvas, Offset.zero);
      canvas.restore();
    }
    painter.dispose();
  }

  @override
  bool shouldRepaint(_RulerPainter oldDelegate) =>
      oldDelegate.scale != scale ||
      oldDelegate.offset != offset ||
      oldDelegate.background != background ||
      oldDelegate.tick != tick ||
      oldDelegate.labelStyle != labelStyle;
}
