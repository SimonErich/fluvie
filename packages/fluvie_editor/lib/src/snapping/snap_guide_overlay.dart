import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/snapping/snap_line.dart';
import 'package:fluvie_editor/src/widgets/canvas_viewport.dart';
import 'package:obers_ui/obers_ui.dart' show OiBuildContextThemeExt;

// obers_ui upstream candidate: a snap-line overlay for any snapping canvas
// (typed lines in, accent lines out, a brief pulse on every new snap).

/// The smart-guide layer during a drag: draws the engine's active
/// [SnapLine]s across the viewport in accent color, and pulses briefly
/// whenever a line appears that was not active on the previous update.
///
/// The pulse rides an [AnimationController], so tests drive it with pumped
/// time — no wall clock.
final class SnapGuideOverlay extends StatefulWidget {
  /// Shows [lines] (canvas positions) under [viewport]'s camera.
  const SnapGuideOverlay({required this.lines, required this.viewport, super.key});

  /// The active snap lines, in canvas coordinates.
  final List<SnapLine> lines;

  /// The camera mapping canvas to viewport pixels.
  final CanvasViewportController viewport;

  @override
  State<SnapGuideOverlay> createState() => _SnapGuideOverlayState();
}

final class _SnapGuideOverlayState extends State<SnapGuideOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    value: 1,
  );

  @override
  void initState() {
    super.initState();
    if (widget.lines.isNotEmpty) _pulse.forward(from: 0);
  }

  @override
  void didUpdateWidget(SnapGuideOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lines.any((line) => !oldWidget.lines.contains(line))) {
      _pulse.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      size: Size.infinite,
      painter: _SnapLinePainter(
        lines: widget.lines,
        viewport: widget.viewport,
        pulse: _pulse,
        color: context.colors.accent.base,
      ),
    ),
  );
}

final class _SnapLinePainter extends CustomPainter {
  _SnapLinePainter({
    required this.lines,
    required this.viewport,
    required this.pulse,
    required this.color,
  }) : super(repaint: Listenable.merge([pulse, viewport]));

  final List<SnapLine> lines;
  final CanvasViewportController viewport;
  final AnimationController pulse;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // A fresh snap flashes wider and fades to a hairline.
    final flash = 1 - pulse.value;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1 + 2 * flash;
    for (final line in lines) {
      switch (line.orientation) {
        case SnapOrientation.vertical:
          final x = viewport.toViewport(Offset(line.position, 0)).dx;
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        case SnapOrientation.horizontal:
          final y = viewport.toViewport(Offset(0, line.position)).dy;
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SnapLinePainter oldDelegate) =>
      oldDelegate.lines != lines || oldDelegate.color != color;
}
