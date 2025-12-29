import 'package:flutter/widgets.dart';

import '../../../presentation/time_consumer.dart';
import '../../../presentation/video_composition.dart';
import 'animation_context.dart';
import 'positioned_animation.dart';

/// A Positioned widget with automatic entry and exit animations.
///
/// [FrameAnimatedPositioned] combines the positioning capabilities of [Positioned]
/// with automatic entry/exit animations. It also provides [AnimationContext]
/// to its children for coordinated timing.
///
/// Note: Named FrameAnimatedPositioned to avoid conflict with Flutter's
/// built-in AnimatedPositioned widget which uses duration-based animation.
///
/// ## Example
///
/// ```dart
/// // Fill parent with slide-from-bottom entry
/// FrameAnimatedPositioned.fill(
///   startFrame: 30,
///   entryAnimation: PositionedAnimation.slideFromBottom(duration: 20),
///   child: Container(color: Colors.blue),
/// )
///
/// // Custom positioning with scale entry
/// FrameAnimatedPositioned(
///   left: 100,
///   top: 50,
///   width: 200,
///   height: 150,
///   startFrame: 0,
///   endFrame: 120,
///   entryAnimation: PositionedAnimation.scaleIn(duration: 25),
///   child: Card(child: Text('Hello')),
/// )
/// ```
class FrameAnimatedPositioned extends StatelessWidget {
  /// The child widget to animate.
  final Widget child;

  // Position properties (same as Positioned)
  /// Distance from the left edge of the parent.
  final double? left;

  /// Distance from the top edge of the parent.
  final double? top;

  /// Distance from the right edge of the parent.
  final double? right;

  /// Distance from the bottom edge of the parent.
  final double? bottom;

  /// Width of the positioned element.
  final double? width;

  /// Height of the positioned element.
  final double? height;

  // Timing properties
  /// Frame at which this widget becomes visible.
  final int? startFrame;

  /// Frame at which this widget becomes invisible.
  final int? endFrame;

  /// Entry animation applied when [startFrame] is reached.
  final PositionedAnimation? entryAnimation;

  /// Exit animation applied before [endFrame].
  ///
  /// If null and [autoReverseExit] is true, uses [entryAnimation.reversed].
  final PositionedAnimation? exitAnimation;

  /// Whether to automatically reverse the entry animation for exit.
  ///
  /// Only applies if [exitAnimation] is null and [entryAnimation] is set.
  final bool autoReverseExit;

  /// Additional offset for child animations using [AnimationContext].
  ///
  /// This value is added to the inherited offset when providing context
  /// to children. Use this to create staggered effects.
  final int childAnimationOffset;

  /// Creates an animated positioned widget.
  const FrameAnimatedPositioned({
    super.key,
    required this.child,
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.width,
    this.height,
    this.startFrame,
    this.endFrame,
    this.entryAnimation,
    this.exitAnimation,
    this.autoReverseExit = true,
    this.childAnimationOffset = 0,
  });

  /// Creates a FrameAnimatedPositioned that fills its parent.
  const FrameAnimatedPositioned.fill({
    super.key,
    required this.child,
    this.startFrame,
    this.endFrame,
    this.entryAnimation,
    this.exitAnimation,
    this.autoReverseExit = true,
    this.childAnimationOffset = 0,
  }) : left = 0,
       top = 0,
       right = 0,
       bottom = 0,
       width = null,
       height = null;

  /// Creates a FrameAnimatedPositioned from an offset.
  factory FrameAnimatedPositioned.fromOffset({
    Key? key,
    required Widget child,
    required Offset offset,
    double? width,
    double? height,
    int? startFrame,
    int? endFrame,
    PositionedAnimation? entryAnimation,
    PositionedAnimation? exitAnimation,
    bool autoReverseExit = true,
    int childAnimationOffset = 0,
  }) => FrameAnimatedPositioned(
    key: key,
    left: offset.dx,
    top: offset.dy,
    width: width,
    height: height,
    startFrame: startFrame,
    endFrame: endFrame,
    entryAnimation: entryAnimation,
    exitAnimation: exitAnimation,
    autoReverseExit: autoReverseExit,
    childAnimationOffset: childAnimationOffset,
    child: child,
  );

  /// Creates a FrameAnimatedPositioned centered in its parent.
  factory FrameAnimatedPositioned.centered({
    Key? key,
    required Widget child,
    double? width,
    double? height,
    int? startFrame,
    int? endFrame,
    PositionedAnimation? entryAnimation,
    PositionedAnimation? exitAnimation,
    bool autoReverseExit = true,
    int childAnimationOffset = 0,
  }) => FrameAnimatedPositioned(
    key: key,
    left: 0,
    right: 0,
    top: 0,
    bottom: 0,
    width: width,
    height: height,
    startFrame: startFrame,
    endFrame: endFrame,
    entryAnimation: entryAnimation,
    exitAnimation: exitAnimation,
    autoReverseExit: autoReverseExit,
    childAnimationOffset: childAnimationOffset,
    child: Center(child: child),
  );

  @override
  Widget build(BuildContext context) {
    // Get parent animation context for timing inheritance
    final parentContext = AnimationContext.of(context);

    // Calculate effective timing
    int effectiveStartFrame = startFrame ?? 0;
    if (parentContext != null && startFrame == null) {
      // If no explicit start frame, inherit from parent
      effectiveStartFrame = parentContext.effectiveStartFrame();
    }

    final entryDuration = entryAnimation?.duration ?? 0;
    final resolvedExitAnimation =
        exitAnimation ??
        (autoReverseExit && entryAnimation != null
            ? entryAnimation!.reversed
            : null);
    final exitDuration = resolvedExitAnimation?.duration ?? 0;

    return TimeConsumer(
      builder: (context, frame, globalProgress) {
        final composition = VideoComposition.of(context);
        final totalDuration = composition?.durationInFrames ?? 1;
        final endFrameResolved = endFrame ?? totalDuration;

        // Check visibility
        if (frame < effectiveStartFrame || frame >= endFrameResolved) {
          return const SizedBox.shrink();
        }

        Widget animatedChild = child;

        // Entry animation phase
        if (entryAnimation != null &&
            frame < effectiveStartFrame + entryDuration) {
          final progress = (frame - effectiveStartFrame) / entryDuration;
          animatedChild = entryAnimation!.apply(child, progress);
        }
        // Exit animation phase
        else if (resolvedExitAnimation != null &&
            frame >= endFrameResolved - exitDuration) {
          final progress =
              (frame - (endFrameResolved - exitDuration)) / exitDuration;
          animatedChild = resolvedExitAnimation.apply(child, progress);
        }

        // Wrap with AnimationContext for children
        final exitStartFrame = exitDuration > 0
            ? endFrameResolved - exitDuration
            : null;

        animatedChild = AnimationContext(
          contextStartFrame: effectiveStartFrame,
          entryDuration: entryDuration,
          exitDuration: exitDuration,
          exitStartFrame: exitStartFrame,
          contextEndFrame: endFrameResolved,
          inheritedOffset:
              (parentContext?.inheritedOffset ?? 0) + childAnimationOffset,
          child: animatedChild,
        );

        return Positioned(
          left: left,
          top: top,
          right: right,
          bottom: bottom,
          width: width,
          height: height,
          child: animatedChild,
        );
      },
    );
  }
}
