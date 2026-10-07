import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/foundation.dart' show mapEquals;
import 'package:fluvie/fluvie.dart' show Placement, encodePlacement;
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/gizmo/transform_drag.dart';
import 'package:fluvie_editor/src/snapping/snap_engine.dart';
import 'package:fluvie_editor/src/snapping/snap_line.dart';
import 'package:fluvie_editor/src/widgets/gizmo_geometry.dart';

/// One live gizmo gesture, from pointer-down to commit: it owns the
/// [TransformDrag] math, the streaming live placements the canvas overrides
/// with, the near-cursor label, and the single command a release commits.
final class GizmoSession {
  /// Starts the gesture [hit] over [targets] at the canvas-pixel [origin].
  /// Resize and rotate act on [primary]; a body drag moves every target.
  /// A non-null [snapper] snaps moves and resizes (rotation never snaps to
  /// lines).
  GizmoSession.begin({
    required GizmoHit hit,
    required Map<String, GizmoTarget> targets,
    required String primary,
    required Size canvas,
    required Offset origin,
    SnapEngine? snapper,
  }) : _hit = hit,
       _primary = primary,
       _canvas = canvas,
       _starts = {for (final entry in targets.entries) entry.key: entry.value.placement},
       _startRects = {for (final entry in targets.entries) entry.key: entry.value.rect},
       _drag = switch (hit) {
         GizmoBody() => TransformDrag.move(
           targets: targets,
           canvas: canvas,
           origin: origin,
           snapper: snapper,
         ),
         GizmoResize(:final handle) => TransformDrag.resize(
           id: primary,
           target: targets[primary]!,
           canvas: canvas,
           handle: handle,
           snapper: snapper,
         ),
         GizmoRotate() => TransformDrag.rotate(
           id: primary,
           target: targets[primary]!,
           origin: origin,
         ),
       } {
    _live = Map.of(_starts);
  }

  final GizmoHit _hit;
  final String _primary;
  final Size _canvas;
  final TransformDrag _drag;
  final Map<String, Placement> _starts;
  final Map<String, Rect> _startRects;
  late Map<String, Placement> _live;

  /// The latest placements — what the canvas overrides with while dragging.
  Map<String, Placement> get live => _live;

  /// Whether this gesture is a body move (not a resize or a rotation).
  bool get isMove => _hit is GizmoBody;

  /// Feeds the pointer position; returns the new live placements.
  Map<String, Placement> update(
    Offset pointer, {
    bool aspect = false,
    bool fromCenter = false,
    bool snap = false,
    bool bypassSnap = false,
  }) => _live = _drag.update(
    pointer,
    aspect: aspect,
    fromCenter: fromCenter,
    snap: snap,
    bypassSnap: bypassSnap,
  );

  /// What the last update snapped to — the smart-guide overlay's input.
  List<SnapLine> get snapLines => _drag.activeSnapLines;

  /// Whether the gesture actually changed anything.
  bool get changed => !mapEquals(_live, _starts);

  /// The current layout rect of [id] under the live placements, or null.
  Rect? displayRectOf(String id) {
    final placement = _live[id];
    final startRect = _startRects[id];
    if (placement == null || startRect == null) return null;
    return placement.rectFor(_canvas, childSize: startRect.size);
  }

  /// The current rotation of [id] under the live placements, in degrees.
  double displayRotationOf(String id) => _live[id]?.rotation ?? 0;

  /// The near-cursor readout: position while moving, dimensions while
  /// resizing, angle while rotating.
  String get label {
    final rect = displayRectOf(_primary);
    if (rect == null) return '';
    return switch (_hit) {
      GizmoBody() => '${rect.left.round()}, ${rect.top.round()}',
      GizmoResize() => '${rect.width.round()} × ${rect.height.round()}',
      GizmoRotate() => '${displayRotationOf(_primary).round()}°',
    };
  }

  /// The one undo step this gesture commits, or null for a no-op press.
  SetTransformsCommand? commit() {
    if (!changed) return null;
    return SetTransformsCommand(
      transforms: {
        for (final entry in _live.entries) entry.key: encodePlacement(entry.value),
      },
    );
  }
}
