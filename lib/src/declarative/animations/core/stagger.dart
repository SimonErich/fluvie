import 'package:flutter/widgets.dart';
import '../../../presentation/time_consumer.dart';
import 'prop_animation.dart';

/// A widget that staggers animations across multiple children.
///
/// [Stagger] automatically applies delayed animations to each child,
/// creating a cascading effect. Each child starts its animation after
/// the previous one by [staggerDelay] frames.
///
/// Example:
/// ```dart
/// Stagger(
///   staggerDelay: 10,
///   animationDuration: 30,
///   animation: PropAnimation.slideUpFade(),
///   children: [
///     Text('Line 1'),  // Starts at frame 0
///     Text('Line 2'),  // Starts at frame 10
///     Text('Line 3'),  // Starts at frame 20
///   ],
/// )
/// ```
class Stagger extends StatelessWidget {
  /// The children to animate with staggered timing.
  final List<Widget> children;

  /// Frames between each child's animation start.
  final int staggerDelay;

  /// Duration of each child's animation in frames.
  final int animationDuration;

  /// The animation to apply to each child.
  final PropAnimation animation;

  /// Easing curve for the animations.
  final Curve curve;

  /// The direction to lay out children.
  ///
  /// [Axis.vertical] creates a Column, [Axis.horizontal] creates a Row.
  final Axis direction;

  /// Spacing between children.
  final double spacing;

  /// Main axis alignment.
  final MainAxisAlignment mainAxisAlignment;

  /// Cross axis alignment.
  final CrossAxisAlignment crossAxisAlignment;

  /// Main axis size.
  final MainAxisSize mainAxisSize;

  /// Creates a stagger widget.
  const Stagger({
    super.key,
    required this.children,
    this.staggerDelay = 10,
    this.animationDuration = 30,
    this.animation = const TranslateAnimation(
      start: Offset(0, 30),
      end: Offset.zero,
    ),
    this.curve = Curves.easeOut,
    this.direction = Axis.vertical,
    this.spacing = 0,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.min,
  });

  /// Creates a vertical stagger (Column layout).
  const Stagger.vertical({
    super.key,
    required this.children,
    this.staggerDelay = 10,
    this.animationDuration = 30,
    this.animation = const TranslateAnimation(
      start: Offset(0, 30),
      end: Offset.zero,
    ),
    this.curve = Curves.easeOut,
    this.spacing = 0,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.min,
  }) : direction = Axis.vertical;

  /// Creates a horizontal stagger (Row layout).
  const Stagger.horizontal({
    super.key,
    required this.children,
    this.staggerDelay = 10,
    this.animationDuration = 30,
    this.animation = const TranslateAnimation(
      start: Offset(30, 0),
      end: Offset.zero,
    ),
    this.curve = Curves.easeOut,
    this.spacing = 0,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.min,
  }) : direction = Axis.horizontal;

  /// Creates a stagger with slide-up + fade animation.
  factory Stagger.slideUpFade({
    Key? key,
    required List<Widget> children,
    int staggerDelay = 10,
    int animationDuration = 30,
    double distance = 30,
    Curve curve = Curves.easeOut,
    Axis direction = Axis.vertical,
    double spacing = 0,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
  }) {
    return Stagger(
      key: key,
      staggerDelay: staggerDelay,
      animationDuration: animationDuration,
      animation: CombinedAnimation([
        TranslateAnimation(start: Offset(0, distance), end: Offset.zero),
        const FadeAnimation(start: 0.0, end: 1.0),
      ]),
      curve: curve,
      direction: direction,
      spacing: spacing,
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: children,
    );
  }

  /// Creates a stagger with scale + fade animation.
  factory Stagger.scaleFade({
    Key? key,
    required List<Widget> children,
    int staggerDelay = 10,
    int animationDuration = 30,
    double startScale = 0.8,
    Curve curve = Curves.easeOut,
    Axis direction = Axis.vertical,
    double spacing = 0,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
  }) {
    return Stagger(
      key: key,
      staggerDelay: staggerDelay,
      animationDuration: animationDuration,
      animation: CombinedAnimation([
        ScaleAnimation(start: startScale, end: 1.0),
        const FadeAnimation(start: 0.0, end: 1.0),
      ]),
      curve: curve,
      direction: direction,
      spacing: spacing,
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    final staggeredChildren = <Widget>[];

    for (int i = 0; i < children.length; i++) {
      Widget child = _StaggeredItem(
        index: i,
        staggerDelay: staggerDelay,
        animationDuration: animationDuration,
        animation: animation,
        curve: curve,
        child: children[i],
      );

      staggeredChildren.add(child);

      // Add spacing between children
      if (spacing > 0 && i < children.length - 1) {
        staggeredChildren.add(
          direction == Axis.vertical
              ? SizedBox(height: spacing)
              : SizedBox(width: spacing),
        );
      }
    }

    if (direction == Axis.vertical) {
      return Column(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: mainAxisSize,
        children: staggeredChildren,
      );
    } else {
      return Row(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: mainAxisSize,
        children: staggeredChildren,
      );
    }
  }

  /// Calculates the total duration for all children to complete animation.
  int get totalDuration {
    if (children.isEmpty) return 0;
    return (children.length - 1) * staggerDelay + animationDuration;
  }
}

/// Internal widget that applies staggered animation to a single child.
class _StaggeredItem extends StatelessWidget {
  final int index;
  final int staggerDelay;
  final int animationDuration;
  final PropAnimation animation;
  final Curve curve;
  final Widget child;

  const _StaggeredItem({
    required this.index,
    required this.staggerDelay,
    required this.animationDuration,
    required this.animation,
    required this.curve,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return TimeConsumer(
      builder: (context, frame, globalProgress) {
        final startFrame = index * staggerDelay;
        final endFrame = startFrame + animationDuration;

        // Before animation starts
        if (frame < startFrame) {
          // Apply animation at progress 0
          return animation.apply(child, 0.0);
        }

        // After animation completes
        if (frame >= endFrame) {
          return child;
        }

        // During animation
        final rawProgress = (frame - startFrame) / animationDuration;
        final curvedProgress = curve.transform(rawProgress.clamp(0.0, 1.0));

        return animation.apply(child, curvedProgress);
      },
    );
  }
}
