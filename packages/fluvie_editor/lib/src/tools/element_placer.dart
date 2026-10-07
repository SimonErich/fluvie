import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'package:fluvie_editor/src/tools/tool_controller.dart';

/// The default box a click-placement opens with, in canvas pixels.
const Size _clickSize = Size(160, 100);

/// The element JSON [state]'s tool places with a plain click at [point]
/// (canvas pixels), or null for a tool that places nothing. A click places
/// the default-size form centered on the point.
Map<String, Object?>? placeElementAt(ToolState state, Offset point, Size canvas) {
  if (!state.places) return null;
  if (state.tool == EditorTool.text) {
    // A default box, so the fresh element has geometry to edit inside.
    return placeElementIn(
      state,
      Rect.fromCenter(center: point, width: canvas.width * 0.35, height: canvas.height * 0.15),
      canvas,
    );
  }
  final rect = Rect.fromCenter(center: point, width: _clickSize.width, height: _clickSize.height);
  return placeElementIn(state, rect, canvas, from: rect.centerLeft, to: rect.centerRight);
}

/// The drag [end] under a Shift constraint for [shape]: rectangles and
/// ellipses square up (the longer edge wins), lines and arrows snap to
/// 45-degree steps.
Offset constrainedEnd(ShapeVariant shape, Offset start, Offset end) {
  final delta = end - start;
  switch (shape) {
    case ShapeVariant.rectangle:
    case ShapeVariant.ellipse:
      final edge = math.max(delta.dx.abs(), delta.dy.abs());
      return start + Offset(edge * delta.dx.sign, edge * delta.dy.sign);
    case ShapeVariant.line:
    case ShapeVariant.arrow:
      const step = math.pi / 4;
      final angle = (math.atan2(delta.dy, delta.dx) / step).round() * step;
      return start + Offset(math.cos(angle), math.sin(angle)) * delta.distance;
  }
}

/// The element JSON [state]'s tool places over the dragged [bounds] (canvas
/// pixels), or null for a tool that places nothing. [from] and [to] carry
/// the actual drag endpoints for the direction-sensitive shapes (line,
/// arrow); they default to a left-to-right sweep of the bounds.
Map<String, Object?>? placeElementIn(
  ToolState state,
  Rect bounds,
  Size canvas, {
  Offset? from,
  Offset? to,
}) {
  switch (state.tool) {
    case EditorTool.select:
    case EditorTool.hand:
    case EditorTool.media:
    case EditorTool.element:
      return null;
    case EditorTool.text:
      return {
        'type': 'Text',
        'text': 'Text',
        'style': {'color': '#F9FAFB', 'fontSize': 32},
        'transform': {
          'x': bounds.center.dx / canvas.width,
          'y': bounds.center.dy / canvas.height,
          'w': bounds.width / canvas.width,
          'h': bounds.height / canvas.height,
        },
      };
    case EditorTool.shape:
      return _shape(state.shape, bounds, from ?? bounds.centerLeft, to ?? bounds.centerRight);
  }
}

/// The element JSON a picked or dropped media [source] lands as: an `Image`
/// or (for [isVideo]) a `Clip`, sized by the drop [bounds] on [canvas].
Map<String, Object?> placeMediaIn(
  Map<String, Object?> source,
  Rect bounds,
  Size canvas, {
  required bool isVideo,
}) => {
  'type': isVideo ? 'Clip' : 'Image',
  'source': Map<String, Object?>.of(source),
  'fit': 'cover',
  'transform': {
    'x': bounds.center.dx / canvas.width,
    'y': bounds.center.dy / canvas.height,
    'w': bounds.width / canvas.width,
    'h': bounds.height / canvas.height,
  },
};

Map<String, Object?> _shape(ShapeVariant variant, Rect bounds, Offset from, Offset to) =>
    switch (variant) {
      ShapeVariant.rectangle => {
        'type': 'Shape',
        'kind': 'rect',
        'rect': {'x': bounds.left, 'y': bounds.top, 'w': bounds.width, 'h': bounds.height},
      },
      ShapeVariant.ellipse => {
        'type': 'Shape',
        'kind': 'circle',
        'center': {'x': bounds.center.dx, 'y': bounds.center.dy},
        'radius': bounds.shortestSide / 2,
      },
      ShapeVariant.line => {
        'type': 'Shape',
        'kind': 'line',
        'from': {'x': from.dx, 'y': from.dy},
        'to': {'x': to.dx, 'y': to.dy},
      },
      ShapeVariant.arrow => {
        'type': 'Arrow',
        'from': {'x': from.dx, 'y': from.dy},
        'to': {'x': to.dx, 'y': to.dy},
      },
    };
