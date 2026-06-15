import 'package:flutter/animation.dart' show Curve, Curves;

/// Curated, plainly-named easing curves for duration-timed animations.
///
/// Every member is a standard Flutter [Curve], chosen and named for how the
/// motion *feels* rather than for its mathematical family. Non-spring
/// animations default to [Ease.smooth]; pass a different member wherever an
/// `ease:` parameter is accepted:
///
/// ```dart
/// Animation.fadeIn(duration: 0.4.seconds, ease: Ease.snappy)
/// ```
abstract final class Ease {
  /// Constant speed from start to finish; maps to [Curves.linear].
  ///
  /// Mechanical and unopinionated — best for counters, progress bars, and
  /// camera scrubs where any acceleration would read as a glitch.
  static const Curve linear = Curves.linear;

  /// Gentle acceleration, cruise, gentle deceleration; maps to
  /// [Curves.easeInOut].
  ///
  /// **The package default** for every non-spring animation: calm, natural
  /// motion that never draws attention to itself. Identical to [inOut].
  static const Curve smooth = Curves.easeInOut;

  /// Starts fast and brakes hard at the end; maps to [Curves.easeOutCubic].
  ///
  /// Energetic and confident — entrances that should feel quick without a
  /// spring's overshoot.
  static const Curve snappy = Curves.easeOutCubic;

  /// The softest ease-in-out pair; maps to [Curves.easeInOutSine].
  ///
  /// Barely-there acceleration — ambient drifts, slow pans, and background
  /// motion that should stay out of the viewer's way.
  static const Curve gentle = Curves.easeInOutSine;

  /// Accelerates from rest; maps to [Curves.easeIn].
  ///
  /// Builds speed toward the cut — good for exits that fly away. Named with
  /// a trailing underscore because `in` is a reserved word in Dart.
  static const Curve in_ = Curves.easeIn;

  /// Decelerates to rest; maps to [Curves.easeOut].
  ///
  /// Arrives softly — the conventional choice for entrances when [smooth]
  /// feels too symmetric.
  static const Curve out = Curves.easeOut;

  /// Accelerates then decelerates; maps to [Curves.easeInOut].
  ///
  /// The same curve as [smooth], under its conventional name for readers who
  /// think in ease-in/ease-out vocabulary.
  static const Curve inOut = Curves.easeInOut;

  /// Overshoots slightly past the target, then settles back; maps to
  /// [Curves.easeOutBack].
  ///
  /// A single playful flourish without a full spring's physics.
  static const Curve back = Curves.easeOutBack;

  /// Drops in and bounces like a ball at the end; maps to [Curves.bounceOut].
  ///
  /// Cartoonish energy — titles and stickers that should land with impact.
  static const Curve bounce = Curves.bounceOut;

  /// Springs past the target and wobbles to rest; maps to
  /// [Curves.elasticOut].
  ///
  /// The most exaggerated member — use sparingly, for moments that deserve
  /// a wink.
  static const Curve elastic = Curves.elasticOut;
}
