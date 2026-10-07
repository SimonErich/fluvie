part of 'transform_drag.dart';

/// The single-element gestures: the rotation-aware resize (pinned opposite
/// edge, aspect lock, from-center, snapping on the dragged edges) and the
/// rotation drag.
extension _SingleTargetMath on TransformDrag {
  Map<String, Placement> _resize(
    Offset pointer, {
    required bool aspect,
    required bool fromCenter,
    required bool bypassSnap,
  }) {
    final entry = _targets.entries.single;
    final start = entry.value;
    final rect = start.rect;
    final moving = _handle!.alignment;
    final fixed = fromCenter ? Alignment.center : Alignment(-moving.x, -moving.y);

    final radians = start.placement.rotation * math.pi / 180;
    final axisU = Offset(math.cos(radians), math.sin(radians));
    final axisV = Offset(-math.sin(radians), math.cos(radians));
    Offset world(Alignment alignment, double width, double height) =>
        rect.center + axisU * (alignment.x * width / 2) + axisV * (alignment.y * height / 2);

    final pinned = world(fixed, rect.width, rect.height);
    final delta = pointer - pinned;
    final du = delta.dx * axisU.dx + delta.dy * axisU.dy;
    final dv = delta.dx * axisV.dx + delta.dy * axisV.dy;
    final factor = fromCenter ? 2.0 : 1.0;
    var width = moving.x == 0 ? rect.width : du * moving.x * factor;
    var height = moving.y == 0 ? rect.height : dv * moving.y * factor;
    if (aspect) {
      final double scale;
      if (moving.x == 0) {
        scale = height / rect.height;
      } else if (moving.y == 0) {
        scale = width / rect.width;
      } else {
        final scaleW = width / rect.width;
        final scaleH = height / rect.height;
        scale = scaleW.abs() >= scaleH.abs() ? scaleW : scaleH;
      }
      width = rect.width * scale;
      height = rect.height * scale;
    }
    width = math.max(width, _minSize);
    height = math.max(height, _minSize);
    final center = pinned - axisU * (fixed.x * width / 2) - axisV * (fixed.y * height / 2);
    final resized = Rect.fromCenter(center: center, width: width, height: height);
    final snapped = _snapResized(
      resized,
      moving,
      aspect: aspect,
      fromCenter: fromCenter,
      bypassSnap: bypassSnap,
      rotation: start.placement.rotation,
    );
    return {entry.key: TransformDrag._placedAt(start.placement, snapped, _canvas, sized: true)};
  }

  /// The resized rect with the dragged edges snapped — only for a plain
  /// axis-aligned resize (no rotation, no aspect lock, no from-center; those
  /// gestures already carry their own modifier intent), and never past
  /// [TransformDrag._minSize].
  Rect _snapResized(
    Rect resized,
    Alignment moving, {
    required bool aspect,
    required bool fromCenter,
    required bool bypassSnap,
    required double rotation,
  }) {
    _activeSnapLines = const [];
    final snapper = _snapper;
    if (snapper == null || aspect || fromCenter || rotation != 0) return resized;
    final result = snapper.snapResize(
      resized,
      movingX: moving.x,
      movingY: moving.y,
      disabled: bypassSnap,
    );
    if (result.rect.width < _minSize || result.rect.height < _minSize) return resized;
    _activeSnapLines = result.lines;
    return result.rect;
  }

  Map<String, Placement> _rotate(Offset pointer, {required bool snap}) {
    final entry = _targets.entries.single;
    final placement = entry.value.placement;
    final center = entry.value.rect.center;
    double angleOf(Offset point) =>
        math.atan2(point.dy - center.dy, point.dx - center.dx) * 180 / math.pi;
    var rotation = placement.rotation + angleOf(pointer) - angleOf(_origin);
    if (snap) rotation = (rotation / 15).roundToDouble() * 15;
    rotation = ((rotation + 180) % 360) - 180;
    return {
      entry.key: Placement(
        x: placement.x,
        y: placement.y,
        width: placement.width,
        height: placement.height,
        rotation: rotation,
        opacity: placement.opacity,
        anchor: placement.anchor,
      ),
    };
  }
}
