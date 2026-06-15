import 'package:flutter/painting.dart' show Alignment, Color;
import 'package:meta/meta.dart' show immutable;

/// A snapshot of animatable property values — the primitive every animation
/// preset is built on.
///
/// Each field is nullable, and `null` means "leave this property at its
/// natural/layout value". A [Keyframe] therefore only ever *overrides* the
/// properties it names:
///
/// ```dart
/// const Keyframe(opacity: 0, y: 0.5) // transparent, half a height down
/// ```
///
/// Offsets are **element-relative**: `x: 1` is one element-width to the
/// right and `y: 1` one element-height down, regardless of resolution, so a
/// slide reads the same on a phone story and a 4K landscape.
@immutable
class Keyframe {
  /// Creates a keyframe that overrides exactly the properties passed as
  /// non-null; everything left `null` keeps its natural value.
  const Keyframe({
    this.opacity,
    this.x,
    this.y,
    this.scale,
    this.scaleX,
    this.scaleY,
    this.rotation,
    this.skewX,
    this.skewY,
    this.blur,
    this.color,
    this.origin = Alignment.center,
  });

  /// The identity keyframe: every field `null`, [origin] centered.
  ///
  /// Animating to (or from) [natural] means "the element exactly as laid
  /// out" — no opacity, transform, blur, or color override at all.
  static const Keyframe natural = Keyframe();

  /// Opacity from `0` (transparent) to `1` (opaque).
  final double? opacity;

  /// Horizontal offset as a fraction of the element's own width
  /// (`x: 1` = one width to the right).
  final double? x;

  /// Vertical offset as a fraction of the element's own height
  /// (`y: 1` = one height down).
  final double? y;

  /// Uniform scale factor (`1` = natural size).
  final double? scale;

  /// Horizontal scale factor (`1` = natural width).
  final double? scaleX;

  /// Vertical scale factor (`1` = natural height).
  final double? scaleY;

  /// Rotation in turns (`1.0` = 360°).
  final double? rotation;

  /// Horizontal skew, in turns of shear angle.
  final double? skewX;

  /// Vertical skew, in turns of shear angle.
  final double? skewY;

  /// Gaussian blur sigma in logical pixels.
  final double? blur;

  /// Color override for color-capable elements (text, shapes, icons).
  final Color? color;

  /// The transform origin for scale/rotation/skew. Never `null`; defaults to
  /// [Alignment.center].
  final Alignment origin;

  /// Merges two keyframes: for every nullable field, [other]'s non-null
  /// value wins, otherwise this keyframe's value is kept.
  ///
  /// [origin] is non-nullable, so it **always comes from the right
  /// operand** — `k + Keyframe.natural` resets the origin to
  /// [Alignment.center] while keeping all of `k`'s other fields.
  Keyframe operator +(Keyframe other) => Keyframe(
    opacity: other.opacity ?? opacity,
    x: other.x ?? x,
    y: other.y ?? y,
    scale: other.scale ?? scale,
    scaleX: other.scaleX ?? scaleX,
    scaleY: other.scaleY ?? scaleY,
    rotation: other.rotation ?? rotation,
    skewX: other.skewX ?? skewX,
    skewY: other.skewY ?? skewY,
    blur: other.blur ?? blur,
    color: other.color ?? color,
    origin: other.origin,
  );

  /// Linearly interpolates between [a] and [b] at position [t].
  ///
  /// Per numeric field: if both sides are `null` the result stays `null`
  /// ("leave natural"); if only one side is `null`, that side is substituted
  /// with the field's natural identity (opacity `1`, offsets `0`, scales
  /// `1`, rotation/skews `0`, blur `0`) before interpolating. [color]
  /// follows [Color.lerp] (a `null` side fades through transparency), and
  /// [origin] follows [Alignment.lerp].
  ///
  /// Values of [t] outside `[0, 1]` extrapolate linearly along the same
  /// line; nothing is clamped.
  // The spec fixes the Flutter-style `lerp(a, b, t)` static (cf. Color.lerp,
  // Alignment.lerp), so the constructor-preferring lint does not apply here.
  // ignore: prefer_constructors_over_static_methods
  static Keyframe lerp(Keyframe a, Keyframe b, double t) => Keyframe(
    opacity: _lerpField(a.opacity, b.opacity, t, 1),
    x: _lerpField(a.x, b.x, t, 0),
    y: _lerpField(a.y, b.y, t, 0),
    scale: _lerpField(a.scale, b.scale, t, 1),
    scaleX: _lerpField(a.scaleX, b.scaleX, t, 1),
    scaleY: _lerpField(a.scaleY, b.scaleY, t, 1),
    rotation: _lerpField(a.rotation, b.rotation, t, 0),
    skewX: _lerpField(a.skewX, b.skewX, t, 0),
    skewY: _lerpField(a.skewY, b.skewY, t, 0),
    blur: _lerpField(a.blur, b.blur, t, 0),
    color: Color.lerp(a.color, b.color, t),
    origin: Alignment.lerp(a.origin, b.origin, t)!,
  );

  static double? _lerpField(double? a, double? b, double t, double identity) {
    if (a == null && b == null) return null;
    final from = a ?? identity;
    final to = b ?? identity;
    return from + (to - from) * t;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Keyframe &&
          other.opacity == opacity &&
          other.x == x &&
          other.y == y &&
          other.scale == scale &&
          other.scaleX == scaleX &&
          other.scaleY == scaleY &&
          other.rotation == rotation &&
          other.skewX == skewX &&
          other.skewY == skewY &&
          other.blur == blur &&
          other.color == color &&
          other.origin == origin;

  @override
  int get hashCode => Object.hash(
    opacity,
    x,
    y,
    scale,
    scaleX,
    scaleY,
    rotation,
    skewX,
    skewY,
    blur,
    color,
    origin,
  );

  @override
  String toString() {
    final parts = <String>[
      if (opacity != null) 'opacity: $opacity',
      if (x != null) 'x: $x',
      if (y != null) 'y: $y',
      if (scale != null) 'scale: $scale',
      if (scaleX != null) 'scaleX: $scaleX',
      if (scaleY != null) 'scaleY: $scaleY',
      if (rotation != null) 'rotation: $rotation',
      if (skewX != null) 'skewX: $skewX',
      if (skewY != null) 'skewY: $skewY',
      if (blur != null) 'blur: $blur',
      if (color != null) 'color: $color',
      if (origin != Alignment.center) 'origin: $origin',
    ];
    return 'Keyframe(${parts.join(', ')})';
  }
}
