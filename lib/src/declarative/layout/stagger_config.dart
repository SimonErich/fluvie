import 'package:flutter/widgets.dart';

/// Configuration for staggered child animations in VRow and VColumn.
///
/// [StaggerConfig] defines how children should animate in sequence,
/// with a delay between each child's animation start.
///
/// Example:
/// ```dart
/// VColumn(
///   stagger: StaggerConfig(
///     delay: 10,
///     duration: 30,
///     curve: Curves.easeOut,
///   ),
///   children: [
///     Text('Line 1'),  // Starts at frame 0
///     Text('Line 2'),  // Starts at frame 10
///     Text('Line 3'),  // Starts at frame 20
///   ],
/// )
/// ```
class StaggerConfig {
  /// Frames between each child's animation start.
  final int delay;

  /// Duration of each child's animation in frames.
  ///
  /// If null, uses the default animation duration (typically 20 frames).
  final int? duration;

  /// Easing curve for the staggered animations.
  final Curve curve;

  /// Whether to fade in each child (from 0 to 1 opacity).
  final bool fadeIn;

  /// Whether to slide each child in.
  final bool slideIn;

  /// The slide direction and distance.
  ///
  /// Positive Y values slide up, negative slide down.
  /// Positive X values slide left, negative slide right.
  final Offset slideOffset;

  /// Whether to scale each child in.
  final bool scaleIn;

  /// The starting scale for scale-in animation.
  final double scaleStart;

  /// Creates a stagger configuration.
  const StaggerConfig({
    required this.delay,
    this.duration,
    this.curve = Curves.easeOut,
    this.fadeIn = true,
    this.slideIn = false,
    this.slideOffset = const Offset(0, 30),
    this.scaleIn = false,
    this.scaleStart = 0.8,
  });

  /// Creates a fade-in stagger configuration.
  const StaggerConfig.fade({
    required this.delay,
    this.duration,
    this.curve = Curves.easeOut,
  })  : fadeIn = true,
        slideIn = false,
        slideOffset = const Offset(0, 30),
        scaleIn = false,
        scaleStart = 0.8;

  /// Creates a slide-up stagger configuration.
  ///
  /// Note: This is a non-const constructor to allow computed [slideOffset] values.
  /// For const usage, use the main constructor with [slideOffset] directly.
  StaggerConfig.slideUp({
    required this.delay,
    this.duration,
    this.curve = Curves.easeOut,
    double distance = 30,
  })  : fadeIn = true,
        slideIn = true,
        slideOffset = Offset(0, distance),
        scaleIn = false,
        scaleStart = 0.8;

  /// Creates a slide-down stagger configuration.
  ///
  /// Note: This is a non-const constructor to allow computed [slideOffset] values.
  /// For const usage, use the main constructor with [slideOffset] directly.
  StaggerConfig.slideDown({
    required this.delay,
    this.duration,
    this.curve = Curves.easeOut,
    double distance = 30,
  })  : fadeIn = true,
        slideIn = true,
        slideOffset = Offset(0, -distance),
        scaleIn = false,
        scaleStart = 0.8;

  /// Creates a slide-left stagger configuration.
  StaggerConfig.slideLeft({
    required this.delay,
    this.duration,
    this.curve = Curves.easeOut,
    double distance = 30,
  })  : fadeIn = true,
        slideIn = true,
        slideOffset = Offset(distance, 0),
        scaleIn = false,
        scaleStart = 0.8;

  /// Creates a slide-right stagger configuration.
  StaggerConfig.slideRight({
    required this.delay,
    this.duration,
    this.curve = Curves.easeOut,
    double distance = 30,
  })  : fadeIn = true,
        slideIn = true,
        slideOffset = Offset(-distance, 0),
        scaleIn = false,
        scaleStart = 0.8;

  /// Creates a scale-in stagger configuration.
  StaggerConfig.scale({
    required this.delay,
    this.duration,
    this.curve = Curves.easeOut,
    double start = 0.8,
  })  : fadeIn = true,
        slideIn = false,
        slideOffset = Offset.zero,
        scaleIn = true,
        scaleStart = start;

  /// Creates a combined slide-up + scale stagger configuration.
  StaggerConfig.slideUpScale({
    required this.delay,
    this.duration,
    this.curve = Curves.easeOut,
    double slideDistance = 30,
    this.scaleStart = 0.8,
  })  : fadeIn = true,
        slideIn = true,
        slideOffset = Offset(0, slideDistance),
        scaleIn = true;

  /// The effective animation duration (uses default if not specified).
  int get effectiveDuration => duration ?? 20;

  /// Calculates the start frame for a child at the given index.
  int startFrameForIndex(int index, [int baseFrame = 0]) =>
      baseFrame + (index * delay);

  /// Calculates the end frame for a child at the given index.
  int endFrameForIndex(int index, [int baseFrame = 0]) =>
      startFrameForIndex(index, baseFrame) + effectiveDuration;

  /// Calculates the total duration for a given number of children.
  ///
  /// This is the time from when the first child starts animating
  /// to when the last child finishes.
  int totalDuration(int childCount) {
    if (childCount <= 0) return 0;
    return startFrameForIndex(childCount - 1) + effectiveDuration;
  }
}
