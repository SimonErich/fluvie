/// The reveal geometry of a mask-wipe animation.
///
/// `Animation.maskWipe` grows a mask of this shape from its origin until the
/// element is fully revealed; [circle] is the default.
enum WipeShape {
  /// A circle growing outward from the wipe origin — the default.
  circle,

  /// An axis-aligned rectangle expanding from the wipe origin.
  rect,

  /// A diagonal line sweeping across the element.
  diagonal,
}
