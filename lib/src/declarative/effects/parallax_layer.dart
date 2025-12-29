import 'package:flutter/material.dart';
import '../../presentation/time_consumer.dart';

/// Direction of parallax movement.
enum ParallaxDirection {
  /// Move horizontally based on progress.
  horizontal,

  /// Move vertically based on progress.
  vertical,

  /// Move in both directions.
  both,
}

/// A widget that creates a parallax movement effect based on scene progress.
///
/// The parallax effect creates depth by moving elements at different speeds.
/// Elements with higher [depth] values move more, creating a sense of distance.
///
/// Example:
/// ```dart
/// ParallaxLayer(
///   depth: 0.3,
///   direction: ParallaxDirection.horizontal,
///   maxOffset: 50,
///   child: Image.asset('background.jpg'),
/// )
/// ```
class ParallaxLayer extends StatelessWidget {
  /// The child widget to apply parallax to.
  final Widget child;

  /// Depth of the parallax effect (0.0 = no movement, 1.0 = full movement).
  ///
  /// Higher values make the element appear further away and move more.
  final double depth;

  /// Direction of the parallax movement.
  final ParallaxDirection direction;

  /// Maximum offset in pixels for the parallax movement.
  ///
  /// The actual offset will be `maxOffset * depth * progress`.
  final double maxOffset;

  /// Whether to center the movement (move from -maxOffset/2 to +maxOffset/2).
  ///
  /// If false, moves from 0 to maxOffset.
  final bool centered;

  /// Easing curve for the parallax movement.
  final Curve curve;

  /// Creates a parallax layer widget.
  const ParallaxLayer({
    super.key,
    required this.child,
    this.depth = 0.5,
    this.direction = ParallaxDirection.horizontal,
    this.maxOffset = 50,
    this.centered = true,
    this.curve = Curves.linear,
  });

  @override
  Widget build(BuildContext context) {
    return TimeConsumer(
      builder: (context, frame, progress) {
        final curvedProgress = curve.transform(progress);
        final movement = maxOffset * depth * curvedProgress;

        double dx = 0;
        double dy = 0;

        if (centered) {
          // Move from -maxOffset/2 to +maxOffset/2
          final centeredMovement = movement - (maxOffset * depth / 2);
          switch (direction) {
            case ParallaxDirection.horizontal:
              dx = centeredMovement;
              break;
            case ParallaxDirection.vertical:
              dy = centeredMovement;
              break;
            case ParallaxDirection.both:
              dx = centeredMovement;
              dy = centeredMovement * 0.5; // Less vertical movement
              break;
          }
        } else {
          switch (direction) {
            case ParallaxDirection.horizontal:
              dx = movement;
              break;
            case ParallaxDirection.vertical:
              dy = movement;
              break;
            case ParallaxDirection.both:
              dx = movement;
              dy = movement * 0.5;
              break;
          }
        }

        return Transform.translate(offset: Offset(dx, dy), child: child);
      },
    );
  }
}

/// A container that applies different parallax depths to multiple layers.
///
/// This is useful for creating multi-layer parallax backgrounds.
///
/// Example:
/// ```dart
/// ParallaxStack(
///   maxOffset: 80,
///   children: [
///     ParallaxChild(depth: 0.2, child: BackgroundLayer()),
///     ParallaxChild(depth: 0.5, child: MidgroundLayer()),
///     ParallaxChild(depth: 0.8, child: ForegroundLayer()),
///   ],
/// )
/// ```
class ParallaxStack extends StatelessWidget {
  /// The parallax children to stack.
  final List<ParallaxChild> children;

  /// Maximum offset for all layers.
  final double maxOffset;

  /// Direction of parallax movement for all layers.
  final ParallaxDirection direction;

  /// Whether to center the movement.
  final bool centered;

  /// Creates a parallax stack.
  const ParallaxStack({
    super.key,
    required this.children,
    this.maxOffset = 50,
    this.direction = ParallaxDirection.horizontal,
    this.centered = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: children.map((child) {
        return ParallaxLayer(
          depth: child.depth,
          direction: direction,
          maxOffset: maxOffset,
          centered: centered,
          child: child.child,
        );
      }).toList(),
    );
  }
}

/// A child widget for [ParallaxStack] with its own depth value.
class ParallaxChild {
  /// The depth of this layer (0.0 = no movement, 1.0 = full movement).
  final double depth;

  /// The child widget.
  final Widget child;

  /// Creates a parallax child.
  const ParallaxChild({required this.depth, required this.child});
}
