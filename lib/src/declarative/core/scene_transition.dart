import 'package:flutter/widgets.dart';

/// Defines the type of transition between scenes.
enum SceneTransitionType {
  /// No transition, instant cut.
  none,

  /// Cross-fade between scenes.
  crossFade,

  /// Slide in from the left.
  slideLeft,

  /// Slide in from the right.
  slideRight,

  /// Slide in from the top.
  slideUp,

  /// Slide in from the bottom.
  slideDown,

  /// Scale in from center.
  scale,

  /// Wipe transition.
  wipe,

  /// Zoom warp transition (zoom into scene A, zoom out of scene B).
  zoomWarp,

  /// Color bleed transition (dominant color bleeds between scenes).
  colorBleed,
}

/// Direction for wipe transitions.
enum WipeDirection { leftToRight, rightToLeft, topToBottom, bottomToTop }

/// Configuration for transitions between scenes.
///
/// [SceneTransition] defines how one scene transitions to another,
/// including the type of transition, duration, and easing curve.
///
/// Example:
/// ```dart
/// Scene(
///   transitionIn: SceneTransition.crossFade(durationInFrames: 15),
///   transitionOut: SceneTransition.slideLeft(durationInFrames: 20),
///   children: [...],
/// )
/// ```
class SceneTransition {
  /// The type of transition.
  final SceneTransitionType type;

  /// Duration of the transition in frames.
  final int durationInFrames;

  /// Easing curve for the transition.
  final Curve curve;

  /// Direction for wipe transitions.
  final WipeDirection? wipeDirection;

  /// Maximum zoom level for zoom warp transition.
  final double maxZoom;

  /// Target alignment for zoom warp transition.
  final Alignment? zoomTarget;

  /// Color for color bleed transition.
  final Color? bleedColor;

  /// No transition (instant cut).
  const SceneTransition.none()
      : type = SceneTransitionType.none,
        durationInFrames = 0,
        curve = Curves.linear,
        wipeDirection = null,
        maxZoom = 1.0,
        zoomTarget = null,
        bleedColor = null;

  /// Cross-fade transition.
  const SceneTransition.crossFade({
    this.durationInFrames = 15,
    this.curve = Curves.easeInOut,
  })  : type = SceneTransitionType.crossFade,
        wipeDirection = null,
        maxZoom = 1.0,
        zoomTarget = null,
        bleedColor = null;

  /// Slide in from the left.
  const SceneTransition.slideLeft({
    this.durationInFrames = 20,
    this.curve = Curves.easeInOut,
  })  : type = SceneTransitionType.slideLeft,
        wipeDirection = null,
        maxZoom = 1.0,
        zoomTarget = null,
        bleedColor = null;

  /// Slide in from the right.
  const SceneTransition.slideRight({
    this.durationInFrames = 20,
    this.curve = Curves.easeInOut,
  })  : type = SceneTransitionType.slideRight,
        wipeDirection = null,
        maxZoom = 1.0,
        zoomTarget = null,
        bleedColor = null;

  /// Slide in from the top.
  const SceneTransition.slideUp({
    this.durationInFrames = 20,
    this.curve = Curves.easeInOut,
  })  : type = SceneTransitionType.slideUp,
        wipeDirection = null,
        maxZoom = 1.0,
        zoomTarget = null,
        bleedColor = null;

  /// Slide in from the bottom.
  const SceneTransition.slideDown({
    this.durationInFrames = 20,
    this.curve = Curves.easeInOut,
  })  : type = SceneTransitionType.slideDown,
        wipeDirection = null,
        maxZoom = 1.0,
        zoomTarget = null,
        bleedColor = null;

  /// Scale in from center.
  const SceneTransition.scale({
    this.durationInFrames = 20,
    this.curve = Curves.easeInOut,
  })  : type = SceneTransitionType.scale,
        wipeDirection = null,
        maxZoom = 1.0,
        zoomTarget = null,
        bleedColor = null;

  /// Wipe transition.
  const SceneTransition.wipe({
    this.durationInFrames = 20,
    this.curve = Curves.easeInOut,
    this.wipeDirection = WipeDirection.leftToRight,
  })  : type = SceneTransitionType.wipe,
        maxZoom = 1.0,
        bleedColor = null,
        zoomTarget = null;

  /// Zoom warp transition.
  ///
  /// Creates a cinematic effect where the outgoing scene zooms in dramatically
  /// while the incoming scene zooms out from the center, creating a warp-like
  /// transition through space.
  ///
  /// [maxZoom] controls how far the zoom goes (default 3.0).
  /// [zoomTarget] optionally specifies where to zoom to/from (center if null).
  const SceneTransition.zoomWarp({
    this.durationInFrames = 30,
    this.curve = Curves.easeInOutCubic,
    this.maxZoom = 3.0,
    this.zoomTarget,
  })  : type = SceneTransitionType.zoomWarp,
        wipeDirection = null,
        bleedColor = null;

  /// Color bleed transition.
  ///
  /// Creates a smooth transition where the dominant color from the outgoing
  /// scene "bleeds" into the incoming scene, creating a cohesive color flow.
  ///
  /// [bleedColor] specifies the color to bleed (if null, uses scene's dominant color).
  const SceneTransition.colorBleed({
    this.durationInFrames = 25,
    this.curve = Curves.easeInOut,
    this.bleedColor,
  })  : type = SceneTransitionType.colorBleed,
        wipeDirection = null,
        maxZoom = 1.0,
        zoomTarget = null;

  /// Calculates the progress of this transition at the given frame.
  ///
  /// [frame] is relative to the transition start (0 = transition start).
  /// Returns 0.0 at start, 1.0 at end.
  double progressAt(int frame) {
    if (durationInFrames <= 0) return 1.0;
    return (frame / durationInFrames).clamp(0.0, 1.0);
  }

  /// Applies the curved progress.
  double curvedProgressAt(int frame) {
    return curve.transform(progressAt(frame));
  }
}
