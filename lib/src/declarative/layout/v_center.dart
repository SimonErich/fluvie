import 'package:flutter/widgets.dart';
import 'video_timing_mixin.dart';

/// A video-aware Center widget with timing and fade properties.
///
/// [VCenter] extends Flutter's [Center] with video-specific properties like
/// startFrame, endFrame, and fade transitions.
///
/// Example:
/// ```dart
/// VCenter(
///   startFrame: 30,
///   endFrame: 120,
///   fadeInFrames: 15,
///   child: AnimatedText('Hello World'),
/// )
/// ```
class VCenter extends StatelessWidget with VideoTimingMixin {
  /// The widget below this widget in the tree.
  final Widget child;

  /// How to inscribe the child into the space allocated during layout.
  ///
  /// If non-null, the factor by which to multiply the incoming constraints
  /// before passing them to the child.
  final double? widthFactor;

  /// How to inscribe the child into the space allocated during layout.
  ///
  /// If non-null, the factor by which to multiply the incoming constraints
  /// before passing them to the child.
  final double? heightFactor;

  // Video timing properties
  @override
  final int? startFrame;

  @override
  final int? endFrame;

  @override
  final int fadeInFrames;

  @override
  final int fadeOutFrames;

  @override
  final Curve fadeInCurve;

  @override
  final Curve fadeOutCurve;

  /// Creates a video-aware Center widget.
  const VCenter({
    super.key,
    required this.child,
    this.widthFactor,
    this.heightFactor,
    // Video timing
    this.startFrame,
    this.endFrame,
    this.fadeInFrames = VideoTimingDefaults.fadeInFrames,
    this.fadeOutFrames = VideoTimingDefaults.fadeOutFrames,
    this.fadeInCurve = VideoTimingDefaults.fadeInCurve,
    this.fadeOutCurve = VideoTimingDefaults.fadeOutCurve,
  });

  @override
  Widget build(BuildContext context) {
    final center = Center(
      widthFactor: widthFactor,
      heightFactor: heightFactor,
      child: child,
    );

    return wrapWithTiming(center);
  }
}
