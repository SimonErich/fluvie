/// When an animation plays within its element's window.
///
/// Usually inferred rather than written: `Animation.from(...)` is an [enter],
/// `Animation.to(...)` is an [exit], and continuous presets such as
/// `Animation.float` are [during].
enum AnimationPhase {
  /// Plays at the start of the element's window (an entrance).
  enter,

  /// Plays at the end of the element's window (an exit).
  exit,

  /// Plays continuously across the element's window.
  during,
}
