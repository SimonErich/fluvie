import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'package:fluvie/fluvie.dart' show Placement, decodePlacement, encodePlacement;

/// The pure fraction math behind group and ungroup: a group child's `Placed`
/// resolves its fractions against the group's box, so wrapping and releasing
/// members is a rewrite between frame spaces — pixel-identical both ways.

/// The box a group occupies inside its parent [frame] (pixels).
///
/// No `transform` means the group's `SizedBox.expand` fills the whole frame;
/// an unsized transform resolves the same way (the expand takes whatever box
/// it gets).
Rect groupRectIn(Object? transform, Size frame) {
  if (transform == null) return Offset.zero & frame;
  final placement = decodePlacement(transform);
  return placement.rectFor(frame) ?? placement.rectFor(frame, childSize: frame)!;
}

/// [transform] rewritten from [frame] fractions to fractions of [groupRect]
/// — what a member gets when it enters a group there. Nothing moves: the
/// anchor point and extent stay on the same pixels. A missing transform
/// reads as the centered intrinsic default. Rotation, opacity, and anchor
/// pass through.
///
/// A non-zero [groupRotation] applies the exact inverse of
/// [absolutePlacementJson]'s composition: the member's rect center turns
/// back around the group center and its own rotation shrinks by the
/// group's, so entering a rotated group keeps the member's pixels too
/// (exact for sized members, by-anchor-point for intrinsic ones).
Map<String, Object?> relativePlacementJson(
  Object? transform,
  Rect groupRect,
  Size frame, {
  double groupRotation = 0,
}) {
  final placement = _decoded(transform);
  var anchorPoint = Offset(placement.x * frame.width, placement.y * frame.height);
  var rotation = placement.rotation;
  if (groupRotation != 0) {
    final rect = placement.rectFor(frame);
    if (rect != null) {
      final center = _rotated(rect.center, groupRect.center, -groupRotation);
      anchorPoint =
          center + (placement.anchor.alongSize(rect.size) - rect.size.center(Offset.zero));
    } else {
      anchorPoint = _rotated(anchorPoint, groupRect.center, -groupRotation);
    }
    rotation -= groupRotation;
  }
  final local = anchorPoint - groupRect.topLeft;
  return encodePlacement(
    Placement(
      x: local.dx / groupRect.width,
      y: local.dy / groupRect.height,
      width: placement.width == null ? null : placement.width! * frame.width / groupRect.width,
      height: placement.height == null ? null : placement.height! * frame.height / groupRect.height,
      rotation: rotation,
      opacity: placement.opacity,
      anchor: placement.anchor,
    ),
  );
}

/// [transform] rewritten from fractions of [groupRect] back to [frame]
/// fractions — what a member gets when its group dissolves. The inverse of
/// [relativePlacementJson].
///
/// A non-zero [groupRotation] composes into the child: its rect center turns
/// around the group center and its own rotation grows by the group's (exact
/// for sized children; an intrinsic child turns by its anchor point, which
/// is exact for the default center anchor).
Map<String, Object?> absolutePlacementJson(
  Object? transform,
  Rect groupRect,
  Size frame, {
  double groupRotation = 0,
}) {
  final placement = _decoded(transform);
  var anchorPoint =
      groupRect.topLeft + Offset(placement.x * groupRect.width, placement.y * groupRect.height);
  var rotation = placement.rotation;
  if (groupRotation != 0) {
    final rect = placement.rectFor(groupRect.size)?.shift(groupRect.topLeft);
    if (rect != null) {
      final center = _rotated(rect.center, groupRect.center, groupRotation);
      anchorPoint =
          center + (placement.anchor.alongSize(rect.size) - rect.size.center(Offset.zero));
    } else {
      anchorPoint = _rotated(anchorPoint, groupRect.center, groupRotation);
    }
    rotation += groupRotation;
  }
  return encodePlacement(
    Placement(
      x: anchorPoint.dx / frame.width,
      y: anchorPoint.dy / frame.height,
      width: placement.width == null ? null : placement.width! * groupRect.width / frame.width,
      height: placement.height == null ? null : placement.height! * groupRect.height / frame.height,
      rotation: rotation,
      opacity: placement.opacity,
      anchor: placement.anchor,
    ),
  );
}

Placement _decoded(Object? transform) =>
    transform == null ? const Placement(x: 0.5, y: 0.5) : decodePlacement(transform);

/// [point] turned clockwise around [about] by [degrees] — the same rotation
/// convention `Placed` renders with.
Offset _rotated(Offset point, Offset about, double degrees) {
  final radians = degrees * math.pi / 180;
  final cosine = math.cos(radians);
  final sine = math.sin(radians);
  final local = point - about;
  return about + Offset(local.dx * cosine - local.dy * sine, local.dx * sine + local.dy * cosine);
}
