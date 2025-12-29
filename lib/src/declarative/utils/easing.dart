import 'package:flutter/animation.dart';

/// Common easing curves with semantic names for video animations.
///
/// This class provides easy access to frequently used animation curves,
/// including standard Flutter curves and custom cubic bezier curves
/// commonly used in motion graphics and video editing.
///
/// Example:
/// ```dart
/// AnimatedProp(
///   duration: 30,
///   animation: PropAnimation.translate(start: Offset(0, 50), end: Offset.zero),
///   curve: Easing.easeOutCubic,
///   child: Text('Hello'),
/// )
/// ```
class Easing {
  Easing._(); // Prevent instantiation

  // ═══════════════════════════════════════════════════════════════════════════
  // STANDARD CURVES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Linear interpolation with no easing.
  static const Curve linear = Curves.linear;

  /// Standard ease-in curve (slow start, fast end).
  static const Curve easeIn = Curves.easeIn;

  /// Standard ease-out curve (fast start, slow end).
  static const Curve easeOut = Curves.easeOut;

  /// Standard ease-in-out curve (slow start and end).
  static const Curve easeInOut = Curves.easeInOut;

  // ═══════════════════════════════════════════════════════════════════════════
  // CUBIC CURVES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Cubic ease-in (more pronounced slow start).
  static const Curve easeInCubic = Cubic(0.32, 0.0, 0.67, 0.0);

  /// Cubic ease-out (more pronounced slow end).
  static const Curve easeOutCubic = Cubic(0.33, 1.0, 0.68, 1.0);

  /// Cubic ease-in-out (more pronounced slow start and end).
  static const Curve easeInOutCubic = Cubic(0.65, 0.0, 0.35, 1.0);

  // ═══════════════════════════════════════════════════════════════════════════
  // EXPONENTIAL CURVES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Exponential ease-in (very slow start, very fast end).
  static const Curve easeInExpo = Cubic(0.7, 0.0, 0.84, 0.0);

  /// Exponential ease-out (very fast start, very slow end).
  static const Curve easeOutExpo = Cubic(0.16, 1.0, 0.3, 1.0);

  /// Exponential ease-in-out.
  static const Curve easeInOutExpo = Cubic(0.87, 0.0, 0.13, 1.0);

  // ═══════════════════════════════════════════════════════════════════════════
  // BACK CURVES (OVERSHOOT)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Ease-in with slight overshoot at the start.
  static const Curve easeInBack = Cubic(0.36, 0.0, 0.66, -0.56);

  /// Ease-out with slight overshoot at the end.
  /// Great for elements that "pop" into place.
  static const Curve easeOutBack = Cubic(0.34, 1.56, 0.64, 1.0);

  /// Ease-in-out with overshoot at both ends.
  static const Curve easeInOutBack = Cubic(0.68, -0.6, 0.32, 1.6);

  // ═══════════════════════════════════════════════════════════════════════════
  // SPECIAL CURVES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Elastic curve with spring-like motion.
  /// Use sparingly - creates a bouncy, oscillating effect.
  static const Curve elastic = ElasticOutCurve();

  /// Elastic ease-in curve.
  static const Curve elasticIn = ElasticInCurve();

  /// Elastic ease-in-out curve.
  static const Curve elasticInOut = ElasticInOutCurve();

  /// Bounce curve - like a ball bouncing.
  static const Curve bounce = Curves.bounceOut;

  /// Bounce ease-in curve.
  static const Curve bounceIn = Curves.bounceIn;

  /// Bounce ease-in-out curve.
  static const Curve bounceInOut = Curves.bounceInOut;

  // ═══════════════════════════════════════════════════════════════════════════
  // SINE CURVES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Sine ease-in curve (gentle).
  static const Curve easeInSine = Cubic(0.12, 0.0, 0.39, 0.0);

  /// Sine ease-out curve (gentle).
  static const Curve easeOutSine = Cubic(0.61, 1.0, 0.88, 1.0);

  /// Sine ease-in-out curve (gentle).
  static const Curve easeInOutSine = Cubic(0.37, 0.0, 0.63, 1.0);

  // ═══════════════════════════════════════════════════════════════════════════
  // QUART/QUINT CURVES (STRONGER EASING)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Quartic ease-out (stronger than cubic).
  static const Curve easeOutQuart = Cubic(0.25, 1.0, 0.5, 1.0);

  /// Quintic ease-out (strongest standard easing).
  static const Curve easeOutQuint = Cubic(0.22, 1.0, 0.36, 1.0);

  // ═══════════════════════════════════════════════════════════════════════════
  // CIRC CURVES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Circular ease-in curve.
  static const Curve easeInCirc = Cubic(0.55, 0.0, 1.0, 0.45);

  /// Circular ease-out curve.
  static const Curve easeOutCirc = Cubic(0.0, 0.55, 0.45, 1.0);

  /// Circular ease-in-out curve.
  static const Curve easeInOutCirc = Cubic(0.85, 0.0, 0.15, 1.0);

  // ═══════════════════════════════════════════════════════════════════════════
  // STEPPED/DISCRETE CURVES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Instant jump at the start.
  static const Curve stepStart = Threshold(0.0);

  /// Instant jump at the end.
  static const Curve stepEnd = Threshold(1.0);

  // ═══════════════════════════════════════════════════════════════════════════
  // FLUTTER BUILT-IN CURVES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fast start, slow middle, fast end.
  static const Curve fastOutSlowIn = Curves.fastOutSlowIn;

  /// Slow start, fast middle, slow end.
  static const Curve slowMiddle = Curves.slowMiddle;

  /// Decelerate curve.
  static const Curve decelerate = Curves.decelerate;

  /// Fast linear to slow ease-in.
  static const Curve fastLinearToSlowEaseIn = Curves.fastLinearToSlowEaseIn;
}
