import 'package:flutter/material.dart';
import 'time_consumer.dart';

/// A transition that cross-fades between two children.
///
/// The transition smoothly fades [child1] out while fading [child2] in
/// over the course of [durationInFrames].
///
/// Example:
/// ```dart
/// Sequence(
///   startFrame: 60,
///   durationInFrames: 30,
///   child: CrossFadeTransition(
///     durationInFrames: 30,
///     child1: Text('Scene 1'),
///     child2: Text('Scene 2'),
///   ),
/// )
/// ```
class CrossFadeTransition extends StatelessWidget {
  /// Duration of the cross-fade in frames.
  final int durationInFrames;

  /// The widget fading out.
  final Widget child1;

  /// The widget fading in.
  final Widget child2;

  /// The curve to use for the fade animation.
  ///
  /// Defaults to [Curves.easeInOut].
  final Curve curve;

  /// Creates a cross-fade transition.
  const CrossFadeTransition({
    super.key,
    required this.durationInFrames,
    required this.child1,
    required this.child2,
    this.curve = Curves.easeInOut,
  });

  @override
  Widget build(BuildContext context) {
    return TimeConsumer(
      builder: (context, frame, globalProgress) {
        // Calculate the progress within this transition (0.0 to 1.0)
        // The progress here comes from the parent Sequence context
        final localProgress = globalProgress.clamp(0.0, 1.0);
        final fadeProgress = curve.transform(localProgress);

        return Stack(
          children: [
            // Child1 fades out
            Opacity(
              opacity: (1.0 - fadeProgress).clamp(0.0, 1.0),
              child: child1,
            ),
            // Child2 fades in
            Opacity(opacity: fadeProgress.clamp(0.0, 1.0), child: child2),
          ],
        );
      },
    );
  }
}

/// A transition that slides one widget out while sliding another in.
///
/// The [direction] controls which way the widgets move.
class SlideTransition extends StatelessWidget {
  /// Duration of the slide in frames.
  final int durationInFrames;

  /// The widget sliding out.
  final Widget child1;

  /// The widget sliding in.
  final Widget child2;

  /// The direction of the slide.
  final AxisDirection direction;

  /// The curve to use for the slide animation.
  final Curve curve;

  /// Creates a slide transition.
  const SlideTransition({
    super.key,
    required this.durationInFrames,
    required this.child1,
    required this.child2,
    this.direction = AxisDirection.left,
    this.curve = Curves.easeInOut,
  });

  @override
  Widget build(BuildContext context) {
    return TimeConsumer(
      builder: (context, frame, globalProgress) {
        final localProgress = globalProgress.clamp(0.0, 1.0);
        final slideProgress = curve.transform(localProgress);

        // Calculate offsets based on direction
        Offset outOffset;
        Offset inOffset;

        switch (direction) {
          case AxisDirection.left:
            outOffset = Offset(-slideProgress, 0);
            inOffset = Offset(1.0 - slideProgress, 0);
            break;
          case AxisDirection.right:
            outOffset = Offset(slideProgress, 0);
            inOffset = Offset(slideProgress - 1.0, 0);
            break;
          case AxisDirection.up:
            outOffset = Offset(0, -slideProgress);
            inOffset = Offset(0, 1.0 - slideProgress);
            break;
          case AxisDirection.down:
            outOffset = Offset(0, slideProgress);
            inOffset = Offset(0, slideProgress - 1.0);
            break;
        }

        return ClipRect(
          child: Stack(
            children: [
              // Child1 slides out
              FractionalTranslation(translation: outOffset, child: child1),
              // Child2 slides in
              FractionalTranslation(translation: inOffset, child: child2),
            ],
          ),
        );
      },
    );
  }
}
