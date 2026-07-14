import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/selection/scene_geometry.dart';
import 'package:fluvie_editor/src/widgets/canvas_viewport.dart';
import 'package:obers_ui/obers_ui.dart' show OiBuildContextThemeExt;

/// The selection's visual layer: an accent bounding box around every
/// selected element and a thin outline under the hovered one — painted in
/// viewport space through the shared camera, never inside the slide.
final class SelectionChrome extends StatelessWidget {
  /// Paints chrome for [selected] and [hovered] using [geometry] under
  /// [viewport]'s camera.
  const SelectionChrome({
    required this.geometry,
    required this.viewport,
    required this.selected,
    required this.hovered,
    super.key,
  });

  /// Where the slide's elements are, in canvas coordinates.
  final SceneGeometry geometry;

  /// The camera mapping canvas to viewport pixels.
  final CanvasViewportController viewport;

  /// The selected element ids.
  final Set<String> selected;

  /// The element under the mouse, or null.
  final String? hovered;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return IgnorePointer(
      child: ListenableBuilder(
        listenable: viewport,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _ChromePainter(
            geometry: geometry,
            viewport: viewport,
            selected: selected,
            hovered: hovered,
            selectionColor: colors.accent.base,
            hoverColor: colors.accent.base.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

final class _ChromePainter extends CustomPainter {
  const _ChromePainter({
    required this.geometry,
    required this.viewport,
    required this.selected,
    required this.hovered,
    required this.selectionColor,
    required this.hoverColor,
  });

  final SceneGeometry geometry;
  final CanvasViewportController viewport;
  final Set<String> selected;
  final String? hovered;
  final Color selectionColor;
  final Color hoverColor;

  @override
  void paint(Canvas canvas, Size size) {
    final hover = hovered;
    if (hover != null && !selected.contains(hover)) {
      _outline(canvas, hover, hoverColor, 1);
    }
    for (final id in selected) {
      _outline(canvas, id, selectionColor, 2);
    }
  }

  void _outline(Canvas canvas, String id, Color color, double width) {
    final shape = geometry.cornersOf(id);
    if (shape == null) return;
    final corners = [for (final corner in shape) viewport.toViewport(corner)];
    final path = Path()..addPolygon(corners, true);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_ChromePainter oldDelegate) =>
      oldDelegate.geometry != geometry ||
      oldDelegate.selected != selected ||
      oldDelegate.hovered != hovered;
}

/// The live marquee rectangle while a drag sweeps the canvas.
final class MarqueeOverlay extends StatelessWidget {
  /// Shows the marquee over [rect] (viewport coordinates).
  const MarqueeOverlay({required this.rect, super.key});

  /// The swept rectangle in viewport pixels.
  final Rect rect;

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.accent.base;
    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            border: Border.all(color: accent),
          ),
        ),
      ),
    );
  }
}
