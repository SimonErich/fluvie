import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/painting.dart' show Alignment;
import 'package:fluvie/fluvie.dart' show Placement;
import 'package:fluvie_editor/src/snapping/snap_engine.dart';
import 'package:fluvie_editor/src/snapping/snap_line.dart';
import 'package:fluvie_editor/src/widgets/gizmo_geometry.dart';

part 'transform_drag_math.dart';

/// One element as the gizmo grabs it: its resolved layout `rect` (canvas
/// pixels, from `SceneGeometry`) and its authored `placement`.
typedef GizmoTarget = ({Rect rect, Placement placement});

enum _DragMode { move, resize, rotate }

/// The pure math of one gizmo gesture: captured at pointer-down, it turns
/// every pointer position into the placements the elements would have —
/// fractions out, ready for a `transform` write or a live override.
///
/// Move works on any selection; resize and rotate work on a single element.
/// Anchors and intrinsic sizing are preserved: a moved intrinsic element
/// stays intrinsic, a resized one becomes sized. An optional [SnapEngine]
/// adjusts moves (by the selection's bounding rect) and resizes (by the
/// dragged edges); [activeSnapLines] carries what it snapped to.
final class TransformDrag {
  /// A body drag moving [targets], starting at [_origin] (canvas pixels).
  TransformDrag.move({
    required Map<String, GizmoTarget> targets,
    required this._canvas,
    required this._origin,
    this._snapper,
  }) : _targets = Map.unmodifiable(targets),
       _handle = null,
       _minSize = 0,
       _bounds = _unionOf(targets),
       _mode = _DragMode.move;

  /// A resize of [id] by [_handle]. The opposite corner or edge stays pinned
  /// (the center under `fromCenter`); sizes clamp at [_minSize] canvas pixels
  /// instead of flipping.
  TransformDrag.resize({
    required String id,
    required GizmoTarget target,
    required this._canvas,
    required GizmoHandle this._handle,
    this._minSize = 1,
    this._snapper,
  }) : _targets = Map.unmodifiable({id: target}),
       _origin = Offset.zero,
       _bounds = null,
       _mode = _DragMode.resize;

  /// A rotation of [id], measured from the pointer's [_origin] angle around
  /// the element center.
  TransformDrag.rotate({required String id, required GizmoTarget target, required this._origin})
    : _targets = Map.unmodifiable({id: target}),
      _canvas = Size.zero,
      _handle = null,
      _minSize = 0,
      _snapper = null,
      _bounds = null,
      _mode = _DragMode.rotate;

  final Map<String, GizmoTarget> _targets;
  final Size _canvas;
  final Offset _origin;
  final GizmoHandle? _handle;
  final double _minSize;
  final SnapEngine? _snapper;
  final Rect? _bounds;
  final _DragMode _mode;

  List<SnapLine> _activeSnapLines = const [];

  /// What the last [update] snapped to (empty while nothing snaps); the
  /// smart-guide overlay draws these.
  List<SnapLine> get activeSnapLines => _activeSnapLines;

  /// The placements for the pointer at [pointer]. [aspect] (Shift) keeps the
  /// resize aspect ratio, [fromCenter] (Alt) resizes around the center,
  /// [snap] (Shift) locks rotation to 15-degree steps, and [bypassSnap]
  /// (Ctrl, Cmd on macOS) disables the snapping engine for a fine nudge.
  Map<String, Placement> update(
    Offset pointer, {
    bool aspect = false,
    bool fromCenter = false,
    bool snap = false,
    bool bypassSnap = false,
  }) => switch (_mode) {
    _DragMode.move => _move(pointer - _origin, bypassSnap: bypassSnap),
    _DragMode.resize => _resize(
      pointer,
      aspect: aspect,
      fromCenter: fromCenter,
      bypassSnap: bypassSnap,
    ),
    _DragMode.rotate => _rotate(pointer, snap: snap),
  };

  /// [targets] shifted by [delta] canvas pixels — the shared math behind
  /// body drags and arrow-key nudges.
  static Map<String, Placement> movedBy(
    Map<String, GizmoTarget> targets,
    Offset delta,
    Size canvas,
  ) => {
    for (final entry in targets.entries)
      entry.key: _placedAt(entry.value.placement, entry.value.rect.shift(delta), canvas),
  };

  /// A body drag: the snapper adjusts the whole selection through its
  /// combined bounding rect, then everything shifts by the adjusted delta.
  Map<String, Placement> _move(Offset delta, {required bool bypassSnap}) {
    var adjusted = delta;
    _activeSnapLines = const [];
    final snapper = _snapper;
    final bounds = _bounds;
    if (snapper != null && bounds != null) {
      final result = snapper.snapMove(bounds.shift(delta), disabled: bypassSnap);
      adjusted = delta + (result.rect.topLeft - bounds.topLeft - delta);
      _activeSnapLines = result.lines;
    }
    return movedBy(_targets, adjusted, _canvas);
  }

  /// The union of the targets' layout rects — what a body drag snaps by.
  static Rect? _unionOf(Map<String, GizmoTarget> targets) {
    Rect? union;
    for (final target in targets.values) {
      union = union == null ? target.rect : union.expandToInclude(target.rect);
    }
    return union;
  }

  /// The placement putting [placement]'s anchor on [rect] — fractions of
  /// [canvas]. A move keeps intrinsic elements intrinsic; a resize
  /// ([sized]) always writes the rect's size.
  static Placement _placedAt(
    Placement placement,
    Rect rect,
    Size canvas, {
    bool sized = false,
  }) {
    final anchorPoint = rect.topLeft + placement.anchor.alongSize(rect.size);
    final keepSize = sized || placement.width != null;
    final keepHeight = sized || placement.height != null;
    return Placement(
      x: anchorPoint.dx / canvas.width,
      y: anchorPoint.dy / canvas.height,
      width: keepSize ? rect.width / canvas.width : null,
      height: keepHeight ? rect.height / canvas.height : null,
      rotation: placement.rotation,
      opacity: placement.opacity,
      anchor: placement.anchor,
    );
  }
}
