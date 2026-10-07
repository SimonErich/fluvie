import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:flutter/painting.dart' show Alignment;
import 'package:flutter/services.dart' show MouseCursor, SystemMouseCursors;
import 'package:meta/meta.dart' show immutable;

// obers_ui upstream candidate: pure transform-gizmo geometry (handle layout,
// hit zones, direction-aware cursors) shared by the overlay painter and the
// canvas input layer.

/// The eight resize handles of a transform gizmo, corners and edge midpoints.
enum GizmoHandle {
  /// The top-left corner.
  topLeft(Alignment.topLeft),

  /// The top edge midpoint.
  top(Alignment.topCenter),

  /// The top-right corner.
  topRight(Alignment.topRight),

  /// The right edge midpoint.
  right(Alignment.centerRight),

  /// The bottom-right corner.
  bottomRight(Alignment.bottomRight),

  /// The bottom edge midpoint.
  bottom(Alignment.bottomCenter),

  /// The bottom-left corner.
  bottomLeft(Alignment.bottomLeft),

  /// The left edge midpoint.
  left(Alignment.centerLeft);

  const GizmoHandle(this.alignment);

  /// Where the handle sits on the unrotated rect, as an [Alignment].
  final Alignment alignment;

  /// Whether this handle resizes both axes (a corner) or one (an edge).
  bool get isCorner => alignment.x != 0 && alignment.y != 0;
}

/// What a pointer position means to the gizmo.
@immutable
sealed class GizmoHit {
  const GizmoHit();
}

/// The pointer is over the element's body: dragging moves it.
final class GizmoBody extends GizmoHit {
  /// The body hit.
  const GizmoBody();

  @override
  bool operator ==(Object other) => other is GizmoBody;

  @override
  int get hashCode => (GizmoBody).hashCode;
}

/// The pointer is on a resize [handle].
final class GizmoResize extends GizmoHit {
  /// A hit on [handle].
  const GizmoResize(this.handle);

  /// The handle under the pointer.
  final GizmoHandle handle;

  @override
  bool operator ==(Object other) => other is GizmoResize && other.handle == handle;

  @override
  int get hashCode => Object.hash(GizmoResize, handle);
}

/// The pointer is in the rotation zone just outside [corner].
final class GizmoRotate extends GizmoHit {
  /// A hit outside [corner].
  const GizmoRotate(this.corner);

  /// The corner whose outside zone the pointer is in.
  final GizmoHandle corner;

  @override
  bool operator ==(Object other) => other is GizmoRotate && other.corner == corner;

  @override
  int get hashCode => Object.hash(GizmoRotate, corner);
}

/// The gizmo's geometry over one element: where the handles are, what a
/// point hits, and which cursor a hit wants — all in canvas coordinates,
/// rotation-aware, and pure.
@immutable
final class GizmoGeometry {
  /// The gizmo over the unrotated layout [rect], turned by [rotation]
  /// degrees (clockwise) around the rect center.
  const GizmoGeometry({required this.rect, this.rotation = 0});

  /// The element's unrotated layout rect.
  final Rect rect;

  /// The element's clockwise rotation in degrees.
  final double rotation;

  /// The canvas position of [handle], rotated with the element.
  Offset handlePoint(GizmoHandle handle) => _rotated(handle.alignment.withinRect(rect));

  /// What [point] hits: resize handles first (nearest within
  /// [handleRadius]), then the rotation zones just outside the corners
  /// (within [rotationRadius]), then the body. Null when nothing is hit.
  /// Radii are canvas units; divide screen-pixel targets by the zoom.
  GizmoHit? hitTest(Offset point, {double handleRadius = 6, double rotationRadius = 16}) {
    GizmoHandle? nearest;
    var best = double.infinity;
    for (final handle in GizmoHandle.values) {
      final distance = (handlePoint(handle) - point).distance;
      if (distance < best) {
        best = distance;
        nearest = handle;
      }
    }
    if (nearest != null && best <= handleRadius) return GizmoResize(nearest);
    if (_contains(point)) return const GizmoBody();
    GizmoHandle? corner;
    var bestCorner = double.infinity;
    for (final handle in GizmoHandle.values) {
      if (!handle.isCorner) continue;
      final distance = (handlePoint(handle) - point).distance;
      if (distance < bestCorner) {
        bestCorner = distance;
        corner = handle;
      }
    }
    if (corner != null && bestCorner <= rotationRadius) return GizmoRotate(corner);
    return null;
  }

  /// The cursor for [hit]: move over the body, grab in the rotation zones,
  /// and a resize cursor matching the handle's on-screen direction (the
  /// element rotation folds in, quantized to 45 degrees).
  MouseCursor cursorFor(GizmoHit hit) => switch (hit) {
    GizmoBody() => SystemMouseCursors.move,
    GizmoRotate() => SystemMouseCursors.grab,
    GizmoResize(:final handle) => _resizeCursor(handle),
  };

  MouseCursor _resizeCursor(GizmoHandle handle) {
    final alignment = handle.alignment;
    final direction = math.atan2(alignment.y, alignment.x) * 180 / math.pi;
    final effective = (((direction + rotation) % 180) + 180) % 180;
    return switch (((effective + 22.5) % 180) ~/ 45) {
      0 => SystemMouseCursors.resizeLeftRight,
      1 => SystemMouseCursors.resizeUpLeftDownRight,
      2 => SystemMouseCursors.resizeUpDown,
      _ => SystemMouseCursors.resizeUpRightDownLeft,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is GizmoGeometry && other.rect == rect && other.rotation == rotation;

  @override
  int get hashCode => Object.hash(rect, rotation);

  Offset _rotated(Offset point) {
    final radians = rotation * math.pi / 180;
    final cosine = math.cos(radians);
    final sine = math.sin(radians);
    final local = point - rect.center;
    return rect.center +
        Offset(local.dx * cosine - local.dy * sine, local.dx * sine + local.dy * cosine);
  }

  bool _contains(Offset point) {
    final radians = -rotation * math.pi / 180;
    final cosine = math.cos(radians);
    final sine = math.sin(radians);
    final local = point - rect.center;
    final unrotated = Offset(
      local.dx * cosine - local.dy * sine,
      local.dx * sine + local.dy * cosine,
    );
    return unrotated.dx.abs() <= rect.width / 2 && unrotated.dy.abs() <= rect.height / 2;
  }
}
