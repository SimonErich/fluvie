import 'package:flutter/widgets.dart';
import '../../../presentation/fade.dart';

/// Base class for property animations that can be applied to widgets.
///
/// [PropAnimation] defines transformations that animate over a progress value
/// from 0.0 to 1.0. Multiple animations can be combined using [PropAnimation.combine].
///
/// Example:
/// ```dart
/// // Single animation
/// PropAnimation.translate(start: Offset(0, 30), end: Offset.zero)
///
/// // Combined animations
/// PropAnimation.combine([
///   PropAnimation.translate(start: Offset(0, 30), end: Offset.zero),
///   PropAnimation.fade(start: 0.0, end: 1.0),
/// ])
/// ```
abstract class PropAnimation {
  const PropAnimation();

  /// Applies the animation to the child widget at the given progress (0.0 to 1.0).
  Widget apply(Widget child, double progress);

  // ---------------------------------------------------------------------------
  // Factory constructors for common animations
  // ---------------------------------------------------------------------------

  /// Creates a translation animation.
  ///
  /// Animates from [start] offset to [end] offset.
  const factory PropAnimation.translate({Offset start, Offset end}) =
      TranslateAnimation;

  /// Creates a scale animation.
  ///
  /// Animates from [start] scale to [end] scale, centered at [alignment].
  const factory PropAnimation.scale({
    double start,
    double end,
    Alignment alignment,
  }) = ScaleAnimation;

  /// Creates a rotation animation.
  ///
  /// Animates from [start] radians to [end] radians, centered at [alignment].
  const factory PropAnimation.rotate({
    double start,
    double end,
    Alignment alignment,
  }) = RotateAnimation;

  /// Creates a fade (opacity) animation.
  ///
  /// Animates from [start] opacity to [end] opacity.
  const factory PropAnimation.fade({double start, double end}) = FadeAnimation;

  /// Creates a combined animation from multiple animations.
  ///
  /// All animations are applied in order.
  const factory PropAnimation.combine(List<PropAnimation> animations) =
      CombinedAnimation;

  // ---------------------------------------------------------------------------
  // Convenience constructors
  // ---------------------------------------------------------------------------

  /// Creates a slide-up animation.
  ///
  /// Slides from [distance] pixels below to the original position.
  static PropAnimation slideUp({double distance = 30}) =>
      PropAnimation.translate(start: Offset(0, distance), end: Offset.zero);

  /// Creates a slide-down animation.
  ///
  /// Slides from [distance] pixels above to the original position.
  static PropAnimation slideDown({double distance = 30}) =>
      PropAnimation.translate(start: Offset(0, -distance), end: Offset.zero);

  /// Creates a slide-left animation.
  ///
  /// Slides from [distance] pixels to the right to the original position.
  static PropAnimation slideLeft({double distance = 30}) =>
      PropAnimation.translate(start: Offset(distance, 0), end: Offset.zero);

  /// Creates a slide-right animation.
  ///
  /// Slides from [distance] pixels to the left to the original position.
  static PropAnimation slideRight({double distance = 30}) =>
      PropAnimation.translate(start: Offset(-distance, 0), end: Offset.zero);

  /// Creates a zoom-in animation.
  ///
  /// Scales from [start] to 1.0.
  static PropAnimation zoomIn({double start = 0.5}) =>
      PropAnimation.scale(start: start, end: 1.0);

  /// Creates a zoom-out animation.
  ///
  /// Scales from 1.0 to [end].
  static PropAnimation zoomOut({double end = 0.5}) =>
      PropAnimation.scale(start: 1.0, end: end);

  /// Creates a fade-in animation.
  ///
  /// Fades from 0.0 to 1.0 opacity.
  static PropAnimation fadeIn() =>
      const PropAnimation.fade(start: 0.0, end: 1.0);

  /// Creates a fade-out animation.
  ///
  /// Fades from 1.0 to 0.0 opacity.
  static PropAnimation fadeOut() =>
      const PropAnimation.fade(start: 1.0, end: 0.0);

  /// Creates a slide-up with fade animation.
  static PropAnimation slideUpFade({double distance = 30}) =>
      PropAnimation.combine([
        PropAnimation.slideUp(distance: distance),
        PropAnimation.fadeIn(),
      ]);

  /// Creates a slide-up with scale animation.
  static PropAnimation slideUpScale({
    double distance = 30,
    double startScale = 0.8,
  }) => PropAnimation.combine([
    PropAnimation.slideUp(distance: distance),
    PropAnimation.zoomIn(start: startScale),
  ]);

  /// Creates a floating animation (for continuous oscillation).
  ///
  /// Use with [Loop] widget for continuous motion.
  static PropAnimation float({
    Offset amplitude = const Offset(0, 10),
    double phase = 0.0,
  }) => FloatAnimation(amplitude: amplitude, phase: phase);

  /// Creates a pulsing scale animation (for continuous oscillation).
  ///
  /// Use with [Loop] widget for continuous motion.
  static PropAnimation pulse({
    double min = 0.95,
    double max = 1.05,
    double phase = 0.0,
  }) => PulseAnimation(min: min, max: max, phase: phase);

  /// Creates a horizontal scale animation (X axis only).
  ///
  /// Useful for squash and stretch effects.
  static PropAnimation scaleX({double start = 0.0, double end = 1.0}) =>
      ScaleXAnimation(start: start, end: end);

  /// Creates a vertical scale animation (Y axis only).
  ///
  /// Useful for squash and stretch effects.
  static PropAnimation scaleY({double start = 0.0, double end = 1.0}) =>
      ScaleYAnimation(start: start, end: end);

  /// Creates a bounce-in animation with overshoot.
  ///
  /// The widget scales past 1.0 to [overshoot] before settling back to 1.0.
  /// Creates a playful, bouncy entrance effect.
  static PropAnimation bounceIn({double start = 0.0, double overshoot = 1.2}) =>
      BounceInAnimation(start: start, overshoot: overshoot);

  /// Creates a slide-down with fade animation.
  ///
  /// Combines a downward slide with a fade-in effect.
  static PropAnimation slideDownFade({double distance = 30}) =>
      PropAnimation.combine([
        PropAnimation.slideDown(distance: distance),
        PropAnimation.fadeIn(),
      ]);

  /// Creates a slide-left with fade animation.
  ///
  /// Combines a leftward slide with a fade-in effect.
  static PropAnimation slideLeftFade({double distance = 30}) =>
      PropAnimation.combine([
        PropAnimation.slideLeft(distance: distance),
        PropAnimation.fadeIn(),
      ]);

  /// Creates a slide-right with fade animation.
  ///
  /// Combines a rightward slide with a fade-in effect.
  static PropAnimation slideRightFade({double distance = 30}) =>
      PropAnimation.combine([
        PropAnimation.slideRight(distance: distance),
        PropAnimation.fadeIn(),
      ]);
}

// -----------------------------------------------------------------------------
// Animation implementations
// -----------------------------------------------------------------------------

/// Translates a widget from [start] to [end] offset.
class TranslateAnimation extends PropAnimation {
  final Offset start;
  final Offset end;

  const TranslateAnimation({this.start = Offset.zero, this.end = Offset.zero});

  @override
  Widget apply(Widget child, double progress) {
    final offset = Offset.lerp(start, end, progress)!;
    if (offset == Offset.zero) return child;
    return Transform.translate(offset: offset, child: child);
  }
}

/// Scales a widget from [start] to [end].
class ScaleAnimation extends PropAnimation {
  final double start;
  final double end;
  final Alignment alignment;

  const ScaleAnimation({
    this.start = 0.0,
    this.end = 1.0,
    this.alignment = Alignment.center,
  });

  @override
  Widget apply(Widget child, double progress) {
    final scale = start + (end - start) * progress;
    if (scale == 1.0) return child;
    return Transform.scale(scale: scale, alignment: alignment, child: child);
  }
}

/// Rotates a widget from [start] to [end] radians.
class RotateAnimation extends PropAnimation {
  final double start;
  final double end;
  final Alignment alignment;

  const RotateAnimation({
    this.start = 0.0,
    this.end = 0.0,
    this.alignment = Alignment.center,
  });

  @override
  Widget apply(Widget child, double progress) {
    final angle = start + (end - start) * progress;
    if (angle == 0.0) return child;
    return Transform.rotate(angle: angle, alignment: alignment, child: child);
  }
}

/// Fades a widget from [start] to [end] opacity.
class FadeAnimation extends PropAnimation {
  final double start;
  final double end;

  const FadeAnimation({this.start = 0.0, this.end = 1.0});

  @override
  Widget apply(Widget child, double progress) {
    final opacity = (start + (end - start) * progress).clamp(0.0, 1.0);
    if (opacity == 1.0) return child;
    if (opacity == 0.0) return Fade(opacity: 0.0, child: child);
    return Fade(opacity: opacity, child: child);
  }
}

/// Combines multiple animations.
class CombinedAnimation extends PropAnimation {
  final List<PropAnimation> animations;

  const CombinedAnimation(this.animations);

  @override
  Widget apply(Widget child, double progress) {
    Widget result = child;
    for (final animation in animations) {
      result = animation.apply(result, progress);
    }
    return result;
  }
}

/// Creates a floating/oscillating motion using sine wave.
class FloatAnimation extends PropAnimation {
  final Offset amplitude;
  final double phase;

  const FloatAnimation({
    this.amplitude = const Offset(0, 10),
    this.phase = 0.0,
  });

  @override
  Widget apply(Widget child, double progress) {
    // Use sine wave for smooth oscillation
    // progress 0->1 maps to 0->2π for one complete cycle
    final sineValue = _sin((progress + phase) * 2 * 3.14159265359);
    final offset = Offset(amplitude.dx * sineValue, amplitude.dy * sineValue);
    return Transform.translate(offset: offset, child: child);
  }

  // Simple sine approximation for predictable rendering
  double _sin(double x) {
    // Normalize to [-π, π]
    while (x > 3.14159265359) {
      x -= 2 * 3.14159265359;
    }
    while (x < -3.14159265359) {
      x += 2 * 3.14159265359;
    }
    // Taylor series approximation (good enough for animations)
    return x -
        (x * x * x) / 6 +
        (x * x * x * x * x) / 120 -
        (x * x * x * x * x * x * x) / 5040;
  }
}

/// Creates a pulsing scale motion using sine wave.
class PulseAnimation extends PropAnimation {
  final double min;
  final double max;
  final double phase;

  const PulseAnimation({this.min = 0.95, this.max = 1.05, this.phase = 0.0});

  @override
  Widget apply(Widget child, double progress) {
    // Map sine [-1, 1] to [min, max]
    final sineValue = _sin((progress + phase) * 2 * 3.14159265359);
    final scale = min + (max - min) * ((sineValue + 1) / 2);
    return Transform.scale(scale: scale, child: child);
  }

  double _sin(double x) {
    while (x > 3.14159265359) {
      x -= 2 * 3.14159265359;
    }
    while (x < -3.14159265359) {
      x += 2 * 3.14159265359;
    }
    return x -
        (x * x * x) / 6 +
        (x * x * x * x * x) / 120 -
        (x * x * x * x * x * x * x) / 5040;
  }
}

/// Scales a widget on the X axis only (horizontal stretch).
class ScaleXAnimation extends PropAnimation {
  final double start;
  final double end;

  const ScaleXAnimation({this.start = 0.0, this.end = 1.0});

  @override
  Widget apply(Widget child, double progress) {
    final scaleX = start + (end - start) * progress;
    if (scaleX == 1.0) return child;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(scaleX, 1.0, 1.0),
      child: child,
    );
  }
}

/// Scales a widget on the Y axis only (vertical stretch).
class ScaleYAnimation extends PropAnimation {
  final double start;
  final double end;

  const ScaleYAnimation({this.start = 0.0, this.end = 1.0});

  @override
  Widget apply(Widget child, double progress) {
    final scaleY = start + (end - start) * progress;
    if (scaleY == 1.0) return child;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(1.0, scaleY, 1.0),
      child: child,
    );
  }
}

/// Creates a bounce-in animation with overshoot effect.
class BounceInAnimation extends PropAnimation {
  final double start;
  final double overshoot;

  const BounceInAnimation({this.start = 0.0, this.overshoot = 1.2});

  @override
  Widget apply(Widget child, double progress) {
    // Custom easing that overshoots then settles
    // Uses a modified curve: fast to overshoot, then ease back to 1.0
    double scale;
    if (progress < 0.6) {
      // Animate from start to overshoot (0 to 0.6 progress)
      final t = progress / 0.6;
      scale = start + (overshoot - start) * t;
    } else {
      // Animate from overshoot back to 1.0 (0.6 to 1.0 progress)
      final t = (progress - 0.6) / 0.4;
      scale = overshoot + (1.0 - overshoot) * t;
    }
    return Transform.scale(scale: scale, child: child);
  }
}
