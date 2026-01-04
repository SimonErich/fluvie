import 'package:flutter/material.dart';
import '../../../presentation/time_consumer.dart';

/// Direction from which an element slides in.
enum SlideDirection {
  /// Slide in from the left.
  fromLeft,

  /// Slide in from the right.
  fromRight,

  /// Slide in from the top.
  fromTop,

  /// Slide in from the bottom.
  fromBottom,
}

/// A widget that animates its child sliding in from a direction.
///
/// This provides an easy way to create entry animations with optional
/// fade and scale effects.
///
/// Example:
/// ```dart
/// SlideIn(
///   direction: SlideDirection.fromLeft,
///   startFrame: 30,
///   duration: 25,
///   distance: 100,
///   fadeIn: true,
///   child: Text('Hello'),
/// )
/// ```
class SlideIn extends StatelessWidget {
  /// The child widget to animate.
  final Widget child;

  /// Direction from which to slide in.
  final SlideDirection direction;

  /// Frame at which the animation starts.
  final int startFrame;

  /// Duration of the animation in frames.
  final int duration;

  /// Distance in pixels to slide.
  final double distance;

  /// Whether to fade in while sliding.
  final bool fadeIn;

  /// Whether to scale up while sliding.
  final bool scaleIn;

  /// Starting scale if [scaleIn] is true.
  final double startScale;

  /// Easing curve for the animation.
  final Curve curve;

  /// Creates a slide-in animation widget.
  const SlideIn({
    super.key,
    required this.child,
    this.direction = SlideDirection.fromBottom,
    this.startFrame = 0,
    this.duration = 30,
    this.distance = 50,
    this.fadeIn = true,
    this.scaleIn = false,
    this.startScale = 0.8,
    this.curve = Curves.easeOutCubic,
  });

  /// Creates a slide-in from the left.
  factory SlideIn.fromLeft({
    Key? key,
    required Widget child,
    int startFrame = 0,
    int duration = 30,
    double distance = 100,
    bool fadeIn = true,
    Curve curve = Curves.easeOutCubic,
  }) {
    return SlideIn(
      key: key,
      direction: SlideDirection.fromLeft,
      startFrame: startFrame,
      duration: duration,
      distance: distance,
      fadeIn: fadeIn,
      curve: curve,
      child: child,
    );
  }

  /// Creates a slide-in from the right.
  factory SlideIn.fromRight({
    Key? key,
    required Widget child,
    int startFrame = 0,
    int duration = 30,
    double distance = 100,
    bool fadeIn = true,
    Curve curve = Curves.easeOutCubic,
  }) {
    return SlideIn(
      key: key,
      direction: SlideDirection.fromRight,
      startFrame: startFrame,
      duration: duration,
      distance: distance,
      fadeIn: fadeIn,
      curve: curve,
      child: child,
    );
  }

  /// Creates a slide-in from the top.
  factory SlideIn.fromTop({
    Key? key,
    required Widget child,
    int startFrame = 0,
    int duration = 30,
    double distance = 80,
    bool fadeIn = true,
    Curve curve = Curves.easeOutCubic,
  }) {
    return SlideIn(
      key: key,
      direction: SlideDirection.fromTop,
      startFrame: startFrame,
      duration: duration,
      distance: distance,
      fadeIn: fadeIn,
      curve: curve,
      child: child,
    );
  }

  /// Creates a slide-in from the bottom.
  factory SlideIn.fromBottom({
    Key? key,
    required Widget child,
    int startFrame = 0,
    int duration = 30,
    double distance = 80,
    bool fadeIn = true,
    Curve curve = Curves.easeOutCubic,
  }) {
    return SlideIn(
      key: key,
      direction: SlideDirection.fromBottom,
      startFrame: startFrame,
      duration: duration,
      distance: distance,
      fadeIn: fadeIn,
      curve: curve,
      child: child,
    );
  }

  /// Creates a slide-in with scale effect.
  factory SlideIn.withScale({
    Key? key,
    required Widget child,
    SlideDirection direction = SlideDirection.fromBottom,
    int startFrame = 0,
    int duration = 30,
    double distance = 50,
    double startScale = 0.8,
    Curve curve = Curves.easeOutCubic,
  }) {
    return SlideIn(
      key: key,
      direction: direction,
      startFrame: startFrame,
      duration: duration,
      distance: distance,
      fadeIn: true,
      scaleIn: true,
      startScale: startScale,
      curve: curve,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return TimeConsumer(
      builder: (context, frame, _) {
        // Calculate animation progress
        final animFrame = frame - startFrame;
        double progress;

        if (animFrame < 0) {
          progress = 0;
        } else if (animFrame >= duration) {
          progress = 1;
        } else {
          progress = animFrame / duration;
        }

        final curvedProgress = curve.transform(progress);

        // Calculate offset based on direction
        Offset offset;
        final remainingDistance = distance * (1 - curvedProgress);

        switch (direction) {
          case SlideDirection.fromLeft:
            offset = Offset(-remainingDistance, 0);
            break;
          case SlideDirection.fromRight:
            offset = Offset(remainingDistance, 0);
            break;
          case SlideDirection.fromTop:
            offset = Offset(0, -remainingDistance);
            break;
          case SlideDirection.fromBottom:
            offset = Offset(0, remainingDistance);
            break;
        }

        // Calculate opacity
        final opacity = fadeIn ? curvedProgress : 1.0;

        // Calculate scale
        final scale =
            scaleIn ? startScale + (1.0 - startScale) * curvedProgress : 1.0;

        Widget result = child;

        // Apply scale if needed
        if (scaleIn) {
          result = Transform.scale(scale: scale, child: result);
        }

        // Apply translation
        result = Transform.translate(offset: offset, child: result);

        // Apply opacity
        if (fadeIn) {
          result = Opacity(opacity: opacity.clamp(0.0, 1.0), child: result);
        }

        return result;
      },
    );
  }
}

/// A widget that animates multiple children sliding in with staggered timing.
///
/// Example:
/// ```dart
/// StaggeredSlideIn(
///   direction: SlideDirection.fromBottom,
///   startFrame: 30,
///   staggerDelay: 10,
///   duration: 25,
///   children: [
///     Text('First'),
///     Text('Second'),
///     Text('Third'),
///   ],
/// )
/// ```
class StaggeredSlideIn extends StatelessWidget {
  /// The children to animate with stagger.
  final List<Widget> children;

  /// Direction from which to slide in.
  final SlideDirection direction;

  /// Frame at which the first child starts animating.
  final int startFrame;

  /// Delay between each child's animation start.
  final int staggerDelay;

  /// Duration of each child's animation.
  final int duration;

  /// Distance in pixels to slide.
  final double distance;

  /// Whether to fade in while sliding.
  final bool fadeIn;

  /// Easing curve for the animation.
  final Curve curve;

  /// Spacing between children (for Column/Row layout).
  final double spacing;

  /// Axis for laying out children.
  final Axis axis;

  /// Main axis alignment.
  final MainAxisAlignment mainAxisAlignment;

  /// Cross axis alignment.
  final CrossAxisAlignment crossAxisAlignment;

  /// Creates a staggered slide-in widget.
  const StaggeredSlideIn({
    super.key,
    required this.children,
    this.direction = SlideDirection.fromBottom,
    this.startFrame = 0,
    this.staggerDelay = 10,
    this.duration = 30,
    this.distance = 50,
    this.fadeIn = true,
    this.curve = Curves.easeOutCubic,
    this.spacing = 0,
    this.axis = Axis.vertical,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final animatedChildren = <Widget>[];

    for (int i = 0; i < children.length; i++) {
      final childStartFrame = startFrame + (i * staggerDelay);

      Widget animatedChild = SlideIn(
        direction: direction,
        startFrame: childStartFrame,
        duration: duration,
        distance: distance,
        fadeIn: fadeIn,
        curve: curve,
        child: children[i],
      );

      animatedChildren.add(animatedChild);

      // Add spacing except for last item
      if (spacing > 0 && i < children.length - 1) {
        animatedChildren.add(
          SizedBox(
            width: axis == Axis.horizontal ? spacing : 0,
            height: axis == Axis.vertical ? spacing : 0,
          ),
        );
      }
    }

    if (axis == Axis.vertical) {
      return Column(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: MainAxisSize.min,
        children: animatedChildren,
      );
    } else {
      return Row(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: MainAxisSize.min,
        children: animatedChildren,
      );
    }
  }
}
