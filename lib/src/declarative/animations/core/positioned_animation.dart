import 'package:flutter/widgets.dart';

/// Direction for edge-based entry/exit animations.
enum EdgeDirection {
  /// Slide from/to the top edge.
  top,

  /// Slide from/to the bottom edge.
  bottom,

  /// Slide from/to the left edge.
  left,

  /// Slide from/to the right edge.
  right,
}

/// Defines a position-based animation with translation, scale, rotation, and opacity.
///
/// [PositionedAnimation] is used by [AnimatedPositioned] to define entry and
/// exit animations. It can be combined and reversed easily.
///
/// ## Example
///
/// ```dart
/// // Slide from bottom with fade
/// PositionedAnimation.slideFromBottom(
///   distance: 100,
///   duration: 30,
///   withFade: true,
/// )
///
/// // Scale in from center
/// PositionedAnimation.scaleIn(
///   startScale: 0.8,
///   duration: 25,
/// )
///
/// // Custom animation
/// PositionedAnimation(
///   translateFrom: Offset(0, 100),
///   translateTo: Offset.zero,
///   scaleFrom: 0.9,
///   scaleTo: 1.0,
///   opacityFrom: 0.0,
///   opacityTo: 1.0,
///   duration: 30,
///   curve: Curves.easeOutCubic,
/// )
/// ```
class PositionedAnimation {
  /// The translation offset at animation start.
  final Offset? translateFrom;

  /// The translation offset at animation end.
  final Offset? translateTo;

  /// Scale at animation start (1.0 = normal size).
  final double? scaleFrom;

  /// Scale at animation end (1.0 = normal size).
  final double? scaleTo;

  /// Rotation in radians at animation start.
  final double? rotateFrom;

  /// Rotation in radians at animation end.
  final double? rotateTo;

  /// Opacity at animation start (0.0 = invisible, 1.0 = fully visible).
  final double? opacityFrom;

  /// Opacity at animation end (0.0 = invisible, 1.0 = fully visible).
  final double? opacityTo;

  /// Duration of the animation in frames.
  final int duration;

  /// Easing curve for the animation.
  final Curve curve;

  /// Alignment for scale and rotation transforms.
  final Alignment alignment;

  /// Creates a positioned animation with custom values.
  const PositionedAnimation({
    this.translateFrom,
    this.translateTo,
    this.scaleFrom,
    this.scaleTo,
    this.rotateFrom,
    this.rotateTo,
    this.opacityFrom,
    this.opacityTo,
    this.duration = 30,
    this.curve = Curves.easeOut,
    this.alignment = Alignment.center,
  });

  /// Creates a slide-in animation from the specified edge.
  ///
  /// [distance] is how far off-screen the element starts.
  /// [withFade] adds opacity animation for a smoother effect.
  factory PositionedAnimation.slideFromEdge({
    required EdgeDirection edge,
    double distance = 100,
    int duration = 30,
    Curve curve = Curves.easeOutCubic,
    bool withFade = true,
  }) {
    Offset translateFrom;
    switch (edge) {
      case EdgeDirection.top:
        translateFrom = Offset(0, -distance);
      case EdgeDirection.bottom:
        translateFrom = Offset(0, distance);
      case EdgeDirection.left:
        translateFrom = Offset(-distance, 0);
      case EdgeDirection.right:
        translateFrom = Offset(distance, 0);
    }
    return PositionedAnimation(
      translateFrom: translateFrom,
      translateTo: Offset.zero,
      opacityFrom: withFade ? 0.0 : null,
      opacityTo: withFade ? 1.0 : null,
      duration: duration,
      curve: curve,
    );
  }

  /// Creates a slide-in animation from the top.
  factory PositionedAnimation.slideFromTop({
    double distance = 100,
    int duration = 30,
    Curve curve = Curves.easeOutCubic,
    bool withFade = true,
  }) =>
      PositionedAnimation.slideFromEdge(
        edge: EdgeDirection.top,
        distance: distance,
        duration: duration,
        curve: curve,
        withFade: withFade,
      );

  /// Creates a slide-in animation from the bottom.
  factory PositionedAnimation.slideFromBottom({
    double distance = 100,
    int duration = 30,
    Curve curve = Curves.easeOutCubic,
    bool withFade = true,
  }) =>
      PositionedAnimation.slideFromEdge(
        edge: EdgeDirection.bottom,
        distance: distance,
        duration: duration,
        curve: curve,
        withFade: withFade,
      );

  /// Creates a slide-in animation from the left.
  factory PositionedAnimation.slideFromLeft({
    double distance = 100,
    int duration = 30,
    Curve curve = Curves.easeOutCubic,
    bool withFade = true,
  }) =>
      PositionedAnimation.slideFromEdge(
        edge: EdgeDirection.left,
        distance: distance,
        duration: duration,
        curve: curve,
        withFade: withFade,
      );

  /// Creates a slide-in animation from the right.
  factory PositionedAnimation.slideFromRight({
    double distance = 100,
    int duration = 30,
    Curve curve = Curves.easeOutCubic,
    bool withFade = true,
  }) =>
      PositionedAnimation.slideFromEdge(
        edge: EdgeDirection.right,
        distance: distance,
        duration: duration,
        curve: curve,
        withFade: withFade,
      );

  /// Creates a scale-in animation with optional fade.
  factory PositionedAnimation.scaleIn({
    double startScale = 0.8,
    int duration = 30,
    Curve curve = Curves.easeOutCubic,
    Alignment alignment = Alignment.center,
    bool withFade = true,
  }) =>
      PositionedAnimation(
        scaleFrom: startScale,
        scaleTo: 1.0,
        opacityFrom: withFade ? 0.0 : null,
        opacityTo: withFade ? 1.0 : null,
        duration: duration,
        curve: curve,
        alignment: alignment,
      );

  /// Creates a scale-out animation with optional fade.
  factory PositionedAnimation.scaleOut({
    double endScale = 0.8,
    int duration = 30,
    Curve curve = Curves.easeInCubic,
    Alignment alignment = Alignment.center,
    bool withFade = true,
  }) =>
      PositionedAnimation(
        scaleFrom: 1.0,
        scaleTo: endScale,
        opacityFrom: withFade ? 1.0 : null,
        opacityTo: withFade ? 0.0 : null,
        duration: duration,
        curve: curve,
        alignment: alignment,
      );

  /// Creates a fade-in animation.
  factory PositionedAnimation.fadeIn({
    int duration = 30,
    Curve curve = Curves.easeOut,
  }) =>
      PositionedAnimation(
        opacityFrom: 0.0,
        opacityTo: 1.0,
        duration: duration,
        curve: curve,
      );

  /// Creates a fade-out animation.
  factory PositionedAnimation.fadeOut({
    int duration = 30,
    Curve curve = Curves.easeIn,
  }) =>
      PositionedAnimation(
        opacityFrom: 1.0,
        opacityTo: 0.0,
        duration: duration,
        curve: curve,
      );

  /// Creates a zoom-in animation (scale from larger).
  factory PositionedAnimation.zoomIn({
    double startScale = 1.2,
    int duration = 30,
    Curve curve = Curves.easeOutCubic,
    Alignment alignment = Alignment.center,
    bool withFade = true,
  }) =>
      PositionedAnimation(
        scaleFrom: startScale,
        scaleTo: 1.0,
        opacityFrom: withFade ? 0.0 : null,
        opacityTo: withFade ? 1.0 : null,
        duration: duration,
        curve: curve,
        alignment: alignment,
      );

  /// Creates a rotation-in animation.
  factory PositionedAnimation.rotateIn({
    double startAngle = -0.1, // About -6 degrees
    int duration = 30,
    Curve curve = Curves.easeOutCubic,
    Alignment alignment = Alignment.center,
    bool withFade = true,
  }) =>
      PositionedAnimation(
        rotateFrom: startAngle,
        rotateTo: 0.0,
        opacityFrom: withFade ? 0.0 : null,
        opacityTo: withFade ? 1.0 : null,
        duration: duration,
        curve: curve,
        alignment: alignment,
      );

  /// Returns the inverse animation (for exit).
  ///
  /// Swaps the from/to values and flips the curve.
  PositionedAnimation get reversed => PositionedAnimation(
        translateFrom: translateTo,
        translateTo: translateFrom,
        scaleFrom: scaleTo,
        scaleTo: scaleFrom,
        rotateFrom: rotateTo,
        rotateTo: rotateFrom,
        opacityFrom: opacityTo,
        opacityTo: opacityFrom,
        duration: duration,
        curve: curve.flipped,
        alignment: alignment,
      );

  /// Creates a copy with different duration.
  PositionedAnimation withDuration(int newDuration) => PositionedAnimation(
        translateFrom: translateFrom,
        translateTo: translateTo,
        scaleFrom: scaleFrom,
        scaleTo: scaleTo,
        rotateFrom: rotateFrom,
        rotateTo: rotateTo,
        opacityFrom: opacityFrom,
        opacityTo: opacityTo,
        duration: newDuration,
        curve: curve,
        alignment: alignment,
      );

  /// Creates a copy with different curve.
  PositionedAnimation withCurve(Curve newCurve) => PositionedAnimation(
        translateFrom: translateFrom,
        translateTo: translateTo,
        scaleFrom: scaleFrom,
        scaleTo: scaleTo,
        rotateFrom: rotateFrom,
        rotateTo: rotateTo,
        opacityFrom: opacityFrom,
        opacityTo: opacityTo,
        duration: duration,
        curve: newCurve,
        alignment: alignment,
      );

  /// Applies the animation at the given progress (0.0 to 1.0).
  ///
  /// Returns the child wrapped in necessary transform widgets.
  Widget apply(Widget child, double progress) {
    Widget result = child;
    final curvedProgress = curve.transform(progress.clamp(0.0, 1.0));

    // Apply rotation
    if (rotateFrom != null && rotateTo != null) {
      final angle = rotateFrom! + (rotateTo! - rotateFrom!) * curvedProgress;
      result = Transform.rotate(
        angle: angle,
        alignment: alignment,
        child: result,
      );
    }

    // Apply scale
    if (scaleFrom != null && scaleTo != null) {
      final scale = scaleFrom! + (scaleTo! - scaleFrom!) * curvedProgress;
      result = Transform.scale(
        scale: scale,
        alignment: alignment,
        child: result,
      );
    }

    // Apply translation
    if (translateFrom != null && translateTo != null) {
      final offset = Offset.lerp(translateFrom!, translateTo!, curvedProgress)!;
      result = Transform.translate(offset: offset, child: result);
    }

    // Apply opacity
    if (opacityFrom != null && opacityTo != null) {
      final opacity =
          (opacityFrom! + (opacityTo! - opacityFrom!) * curvedProgress).clamp(
        0.0,
        1.0,
      );
      result = Opacity(opacity: opacity, child: result);
    }

    return result;
  }

  /// Whether this animation has any transform effects.
  bool get hasTransform =>
      translateFrom != null ||
      scaleFrom != null ||
      rotateFrom != null ||
      opacityFrom != null;
}
