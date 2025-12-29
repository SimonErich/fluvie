import 'package:flutter/widgets.dart';
import 'video_timing_mixin.dart';

/// A video-aware SizedBox widget with timing and fade properties.
///
/// [VSizedBox] extends Flutter's [SizedBox] with video-specific properties like
/// startFrame, endFrame, and fade transitions.
///
/// Example:
/// ```dart
/// VSizedBox(
///   width: 200,
///   height: 100,
///   startFrame: 30,
///   endFrame: 120,
///   child: AnimatedText('Hello World'),
/// )
/// ```
class VSizedBox extends StatelessWidget with VideoTimingMixin {
  /// The widget below this widget in the tree.
  final Widget? child;

  /// The width of the box.
  final double? width;

  /// The height of the box.
  final double? height;

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

  /// Creates a video-aware SizedBox.
  const VSizedBox({
    super.key,
    this.child,
    this.width,
    this.height,
    // Video timing
    this.startFrame,
    this.endFrame,
    this.fadeInFrames = VideoTimingDefaults.fadeInFrames,
    this.fadeOutFrames = VideoTimingDefaults.fadeOutFrames,
    this.fadeInCurve = VideoTimingDefaults.fadeInCurve,
    this.fadeOutCurve = VideoTimingDefaults.fadeOutCurve,
  });

  /// Creates a video-aware SizedBox with the given size.
  VSizedBox.fromSize({
    super.key,
    this.child,
    required Size size,
    // Video timing
    this.startFrame,
    this.endFrame,
    this.fadeInFrames = VideoTimingDefaults.fadeInFrames,
    this.fadeOutFrames = VideoTimingDefaults.fadeOutFrames,
    this.fadeInCurve = VideoTimingDefaults.fadeInCurve,
    this.fadeOutCurve = VideoTimingDefaults.fadeOutCurve,
  }) : width = size.width,
       height = size.height;

  /// Creates a video-aware SizedBox that is as large as its parent allows.
  const VSizedBox.expand({
    super.key,
    this.child,
    // Video timing
    this.startFrame,
    this.endFrame,
    this.fadeInFrames = VideoTimingDefaults.fadeInFrames,
    this.fadeOutFrames = VideoTimingDefaults.fadeOutFrames,
    this.fadeInCurve = VideoTimingDefaults.fadeInCurve,
    this.fadeOutCurve = VideoTimingDefaults.fadeOutCurve,
  }) : width = double.infinity,
       height = double.infinity;

  /// Creates a video-aware SizedBox that will become as small as its parent allows.
  const VSizedBox.shrink({
    super.key,
    this.child,
    // Video timing
    this.startFrame,
    this.endFrame,
    this.fadeInFrames = VideoTimingDefaults.fadeInFrames,
    this.fadeOutFrames = VideoTimingDefaults.fadeOutFrames,
    this.fadeInCurve = VideoTimingDefaults.fadeInCurve,
    this.fadeOutCurve = VideoTimingDefaults.fadeOutCurve,
  }) : width = 0.0,
       height = 0.0;

  /// Creates a square video-aware SizedBox.
  const VSizedBox.square({
    super.key,
    this.child,
    required double dimension,
    // Video timing
    this.startFrame,
    this.endFrame,
    this.fadeInFrames = VideoTimingDefaults.fadeInFrames,
    this.fadeOutFrames = VideoTimingDefaults.fadeOutFrames,
    this.fadeInCurve = VideoTimingDefaults.fadeInCurve,
    this.fadeOutCurve = VideoTimingDefaults.fadeOutCurve,
  }) : width = dimension,
       height = dimension;

  @override
  Widget build(BuildContext context) {
    final sizedBox = SizedBox(width: width, height: height, child: child);

    // Only wrap with timing if timing properties are specified
    if (startFrame != null || endFrame != null) {
      return wrapWithTiming(sizedBox);
    }

    return sizedBox;
  }
}
