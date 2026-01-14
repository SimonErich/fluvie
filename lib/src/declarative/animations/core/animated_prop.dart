import 'package:flutter/widgets.dart';
import '../../../presentation/time_consumer.dart';
import 'animation_context.dart';
import 'prop_animation.dart';

/// A widget that animates its child using frame-based timing.
///
/// [AnimatedProp] applies a [PropAnimation] to its child over a specified
/// duration starting at [startFrame] (or [offsetTime] for relative timing).
///
/// Example:
/// ```dart
/// AnimatedProp(
///   startFrame: 30,
///   duration: 60,
///   animation: PropAnimation.slideUp(),
///   child: Text('Hello'),
/// )
///
/// // Using offsetTime for relative timing within a parent context
/// AnimatedProp(
///   offsetTime: 15,  // Starts 15 frames after parent's start
///   duration: 30,
///   animation: PropAnimation.combine([
///     PropAnimation.fadeIn(),
///     PropAnimation.zoomIn(start: 0.8),
///   ]),
///   child: Image.asset('photo.jpg'),
/// )
/// ```
class AnimatedProp extends StatelessWidget {
  /// The widget to animate.
  final Widget child;

  /// The animation to apply.
  final PropAnimation animation;

  /// Absolute start frame for the animation.
  ///
  /// If null, uses [offsetTime] for relative timing.
  final int? startFrame;

  /// Relative offset from the parent's context start frame.
  ///
  /// Used when [startFrame] is null.
  final int offsetTime;

  /// Duration of the animation in frames.
  final int duration;

  /// Easing curve for the animation.
  final Curve curve;

  /// Whether to auto-reverse the animation.
  ///
  /// When true, the animation plays forward then backward.
  final bool autoReverse;

  /// Whether to loop the animation continuously.
  ///
  /// When true, the animation repeats indefinitely.
  final bool loop;

  /// GlobalKey for hero-style cross-scene transitions.
  final GlobalKey? heroKey;

  /// Creates an animated prop widget.
  const AnimatedProp({
    super.key,
    required this.child,
    required this.animation,
    this.startFrame,
    this.offsetTime = 0,
    this.duration = 30,
    this.curve = Curves.easeOut,
    this.autoReverse = false,
    this.loop = false,
    this.heroKey,
  });

  /// Creates an animated prop with fade-in effect.
  factory AnimatedProp.fadeIn({
    Key? key,
    required Widget child,
    int? startFrame,
    int offsetTime = 0,
    int duration = 30,
    Curve curve = Curves.easeOut,
  }) {
    return AnimatedProp(
      key: key,
      animation: PropAnimation.fadeIn(),
      startFrame: startFrame,
      offsetTime: offsetTime,
      duration: duration,
      curve: curve,
      child: child,
    );
  }

  /// Creates an animated prop with slide-up effect.
  factory AnimatedProp.slideUp({
    Key? key,
    required Widget child,
    double distance = 30,
    int? startFrame,
    int offsetTime = 0,
    int duration = 30,
    Curve curve = Curves.easeOut,
  }) {
    return AnimatedProp(
      key: key,
      animation: PropAnimation.slideUp(distance: distance),
      startFrame: startFrame,
      offsetTime: offsetTime,
      duration: duration,
      curve: curve,
      child: child,
    );
  }

  /// Creates an animated prop with zoom-in effect.
  factory AnimatedProp.zoomIn({
    Key? key,
    required Widget child,
    double startScale = 0.5,
    int? startFrame,
    int offsetTime = 0,
    int duration = 30,
    Curve curve = Curves.easeOut,
  }) {
    return AnimatedProp(
      key: key,
      animation: PropAnimation.zoomIn(start: startScale),
      startFrame: startFrame,
      offsetTime: offsetTime,
      duration: duration,
      curve: curve,
      child: child,
    );
  }

  /// Creates an animated prop with slide-up + fade effect.
  factory AnimatedProp.slideUpFade({
    Key? key,
    required Widget child,
    double distance = 30,
    int? startFrame,
    int offsetTime = 0,
    int duration = 30,
    Curve curve = Curves.easeOut,
  }) {
    return AnimatedProp(
      key: key,
      animation: PropAnimation.slideUpFade(distance: distance),
      startFrame: startFrame,
      offsetTime: offsetTime,
      duration: duration,
      curve: curve,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get parent animation context for timing inheritance
    final animContext = AnimationContext.of(context);

    return TimeConsumer(
      builder: (context, frame, globalProgress) {
        // Calculate effective start frame
        int effectiveStartFrame;
        if (startFrame != null) {
          // Explicit absolute frame specified
          effectiveStartFrame = startFrame!;
        } else if (animContext != null) {
          // Use context-relative timing: start after parent entry completes
          effectiveStartFrame = animContext.effectiveStartFrame(
            offsetFrames: offsetTime,
            afterParentEntry: true,
          );
        } else {
          // No context, use offsetTime as absolute
          effectiveStartFrame = offsetTime;
        }

        final endFrame = effectiveStartFrame + duration;

        // Calculate local progress
        double progress;
        if (frame < effectiveStartFrame) {
          progress = 0.0;
        } else if (duration <= 0) {
          progress = 0.0;
        } else if (frame >= endFrame) {
          if (loop) {
            // Loop: restart from beginning
            final elapsed = frame - effectiveStartFrame;
            final cycleFrame = elapsed % duration;
            progress = cycleFrame / duration;
          } else {
            progress = 1.0;
          }
        } else {
          final elapsed = frame - effectiveStartFrame;
          progress = elapsed / duration;
        }

        // Handle auto-reverse
        if (autoReverse && !loop) {
          // Auto-reverse: animate forward then backward
          if (progress > 0.5) {
            progress = 1.0 - progress;
          }
          progress = progress * 2; // Scale to 0-1 range
        } else if (autoReverse && loop) {
          // Loop with auto-reverse: ping-pong
          final cyclePosition = (progress * 2) % 2;
          if (cyclePosition > 1) {
            progress = 2 - cyclePosition;
          } else {
            progress = cyclePosition;
          }
        }

        // Apply curve
        final curvedProgress = curve.transform(progress.clamp(0.0, 1.0));

        // Apply animation
        Widget result = animation.apply(child, curvedProgress);

        // Wrap with hero key if provided
        if (heroKey != null) {
          result = KeyedSubtree(key: heroKey, child: result);
        }

        return result;
      },
    );
  }
}
