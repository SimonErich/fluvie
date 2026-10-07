import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/widgets/canvas_viewport.dart';
import 'package:fluvie_editor/src/widgets/gizmo_geometry.dart';
import 'package:obers_ui/obers_ui.dart' show OiBuildContextThemeExt;

// obers_ui upstream candidate: the transform-gizmo overlay (selection box,
// eight resize handles, near-cursor readout) for any pan/zoom canvas editor.

/// The gizmo's visual layer: the rotated selection box with its eight
/// resize handles, and an optional near-cursor [label] — painted in
/// viewport space at constant screen size, over an element given in canvas
/// coordinates.
///
/// Purely visual: hit-testing lives in [GizmoGeometry], pointer routing in
/// the canvas input layer.
final class TransformGizmo extends StatelessWidget {
  /// Paints the gizmo over [rect] (canvas space) rotated by [rotation]
  /// degrees, mapped through [viewport]'s camera. [label] (with
  /// [labelAnchor], viewport space) shows the live readout while dragging.
  const TransformGizmo({
    required this.rect,
    required this.viewport,
    this.rotation = 0,
    this.label,
    this.labelAnchor,
    super.key,
  });

  /// The element's unrotated layout rect, in canvas coordinates.
  final Rect rect;

  /// The element's clockwise rotation in degrees.
  final double rotation;

  /// The camera mapping canvas to viewport pixels.
  final CanvasViewportController viewport;

  /// The live readout ("640 × 320", "45°"), or null for none.
  final String? label;

  /// Where the readout anchors, in viewport pixels (usually the pointer).
  final Offset? labelAnchor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return IgnorePointer(
      child: ListenableBuilder(
        listenable: viewport,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _GizmoPainter(
            geometry: GizmoGeometry(rect: rect, rotation: rotation),
            viewport: viewport,
            accent: colors.accent.base,
            handleFill: colors.background,
            label: label,
            labelAnchor: labelAnchor,
            labelStyle: TextStyle(color: colors.text, fontSize: 11),
            labelFill: colors.surface,
          ),
        ),
      ),
    );
  }
}

final class _GizmoPainter extends CustomPainter {
  const _GizmoPainter({
    required this.geometry,
    required this.viewport,
    required this.accent,
    required this.handleFill,
    required this.label,
    required this.labelAnchor,
    required this.labelStyle,
    required this.labelFill,
  });

  final GizmoGeometry geometry;
  final CanvasViewportController viewport;
  final Color accent;
  final Color handleFill;
  final String? label;
  final Offset? labelAnchor;
  final TextStyle labelStyle;
  final Color labelFill;

  static const double _handleSize = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = accent;
    final corners = [
      GizmoHandle.topLeft,
      GizmoHandle.topRight,
      GizmoHandle.bottomRight,
      GizmoHandle.bottomLeft,
    ].map((handle) => viewport.toViewport(geometry.handlePoint(handle))).toList();
    canvas.drawPath(Path()..addPolygon(corners, true), stroke);

    final fill = Paint()..color = handleFill;
    for (final handle in GizmoHandle.values) {
      final center = viewport.toViewport(geometry.handlePoint(handle));
      final square = Rect.fromCenter(center: center, width: _handleSize, height: _handleSize);
      canvas
        ..drawRect(square, fill)
        ..drawRect(square, stroke);
    }
    _paintLabel(canvas);
  }

  void _paintLabel(Canvas canvas) {
    final text = label;
    final anchor = labelAnchor;
    if (text == null || text.isEmpty || anchor == null) return;
    final painter = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    const pad = 4.0;
    final origin = anchor + const Offset(12, 12);
    final bubble = Rect.fromLTWH(
      origin.dx,
      origin.dy,
      painter.width + 2 * pad,
      painter.height + 2 * pad,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bubble, const Radius.circular(3)),
      Paint()..color = labelFill,
    );
    painter.paint(canvas, origin + const Offset(pad, pad));
  }

  @override
  bool shouldRepaint(_GizmoPainter oldDelegate) =>
      oldDelegate.geometry != geometry ||
      oldDelegate.label != label ||
      oldDelegate.labelAnchor != labelAnchor ||
      oldDelegate.accent != accent;
}
