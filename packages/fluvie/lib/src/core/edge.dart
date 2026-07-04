/// A side of an element or frame, used by slide-style animations to say where
/// motion comes from or goes to.
///
/// ```dart
/// Animation.slideFadeIn(from: Edge.bottom)   // rises into place
/// Animation.drift(to: Edge.right)          // drifts off to the right
/// ```
enum Edge {
  /// The top side; entering from here starts above the natural position.
  top,

  /// The bottom side; entering from here starts below the natural position.
  bottom,

  /// The left side; entering from here starts left of the natural position.
  left,

  /// The right side; entering from here starts right of the natural position.
  right;

  /// The horizontal unit offset an element starts at when entering **from**
  /// this edge, as a fraction of its own width.
  ///
  /// `Edge.left` is `-1` (one element-width to the left), `Edge.right` is
  /// `1`; the vertical edges are `0`. Keyframe offsets use the same
  /// fraction-of-element-size convention, so `Keyframe(x: from.dx)` places
  /// the element exactly one element-size off its natural spot.
  double get dx => switch (this) {
    left => -1,
    right => 1,
    top || bottom => 0,
  };

  /// The vertical unit offset an element starts at when entering **from**
  /// this edge, as a fraction of its own height.
  ///
  /// `Edge.top` is `-1` (one element-height above), `Edge.bottom` is `1`;
  /// the horizontal edges are `0`.
  double get dy => switch (this) {
    top => -1,
    bottom => 1,
    left || right => 0,
  };
}
