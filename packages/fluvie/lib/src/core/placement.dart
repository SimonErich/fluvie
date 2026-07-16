import 'dart:ui' show Rect, Size;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart' show Alignment;

/// Where an element sits on the scene canvas, in fractions of the canvas
/// size — the resolution-independent geometry behind the spec's `transform`
/// key and the `Placed` element.
///
/// [x] and [y] locate the element's [anchor] point as canvas fractions
/// (0..1). [width] and [height] size the element as canvas fractions; leave
/// them null and the element keeps its intrinsic size. [rotation] turns the
/// element around its own center, in degrees, after placement.
///
/// [rectFor] is the ONE fraction-to-pixel mapping: `Placed` lays out with
/// it, and editing tools hit-test against it, so rendering and geometry can
/// never drift apart.
@immutable
final class Placement {
  /// Places the [anchor] point at canvas fraction ([x], [y]).
  const Placement({
    required this.x,
    required this.y,
    this.width,
    this.height,
    this.rotation = 0,
    this.anchor = Alignment.center,
  });

  /// The anchor point's horizontal position, as a fraction of canvas width.
  final double x;

  /// The anchor point's vertical position, as a fraction of canvas height.
  final double y;

  /// The element width as a fraction of canvas width, or null for intrinsic.
  final double? width;

  /// The element height as a fraction of canvas height, or null for
  /// intrinsic.
  final double? height;

  /// Clockwise rotation around the element's center, in degrees.
  final double rotation;

  /// Which point of the element sits at ([x], [y]).
  final Alignment anchor;

  /// Whether the element sizes itself (no [width]/[height] given).
  bool get isIntrinsic => width == null || height == null;

  /// The element's unrotated pixel rect on a [canvas] of the given size.
  ///
  /// A sized placement resolves on its own; an intrinsic one needs the
  /// laid-out [childSize] and returns null without it. Rotation does not
  /// change this rect — it turns the element around the rect's center.
  Rect? rectFor(Size canvas, {Size? childSize}) {
    final size = isIntrinsic ? childSize : Size(width! * canvas.width, height! * canvas.height);
    if (size == null) return null;
    final anchorFraction = anchor.alongSize(size);
    return Rect.fromLTWH(
      x * canvas.width - anchorFraction.dx,
      y * canvas.height - anchorFraction.dy,
      size.width,
      size.height,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Placement &&
      other.x == x &&
      other.y == y &&
      other.width == width &&
      other.height == height &&
      other.rotation == rotation &&
      other.anchor == anchor;

  @override
  int get hashCode => Object.hash(x, y, width, height, rotation, anchor);

  @override
  String toString() =>
      'Placement(x: $x, y: $y, w: $width, h: $height, '
      'rotation: $rotation, anchor: $anchor)';
}
