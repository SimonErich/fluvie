import 'package:flutter/widgets.dart';
import 'video_timing_mixin.dart';

/// A video-aware Padding widget with timing and fade properties.
///
/// [VPadding] extends Flutter's [Padding] with video-specific properties like
/// startFrame, endFrame, and fade transitions.
///
/// Example:
/// ```dart
/// VPadding(
///   padding: EdgeInsets.all(20),
///   startFrame: 30,
///   endFrame: 120,
///   child: AnimatedText('Hello World'),
/// )
/// ```
class VPadding extends StatelessWidget with VideoTimingMixin {
  /// The widget below this widget in the tree.
  final Widget child;

  /// The amount of space by which to inset the child.
  final EdgeInsetsGeometry padding;

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

  /// Creates a video-aware Padding widget.
  const VPadding({
    super.key,
    required this.child,
    required this.padding,
    // Video timing
    this.startFrame,
    this.endFrame,
    this.fadeInFrames = VideoTimingDefaults.fadeInFrames,
    this.fadeOutFrames = VideoTimingDefaults.fadeOutFrames,
    this.fadeInCurve = VideoTimingDefaults.fadeInCurve,
    this.fadeOutCurve = VideoTimingDefaults.fadeOutCurve,
  });

  /// Creates a video-aware Padding with uniform padding on all sides.
  ///
  /// Note: Non-const to allow variable [value] parameter.
  /// For const usage, use the main constructor with [EdgeInsets.all] directly.
  VPadding.all(
    double value, {
    super.key,
    required this.child,
    // Video timing
    this.startFrame,
    this.endFrame,
    this.fadeInFrames = VideoTimingDefaults.fadeInFrames,
    this.fadeOutFrames = VideoTimingDefaults.fadeOutFrames,
    this.fadeInCurve = VideoTimingDefaults.fadeInCurve,
    this.fadeOutCurve = VideoTimingDefaults.fadeOutCurve,
  }) : padding = EdgeInsets.all(value);

  /// Creates a video-aware Padding with symmetric horizontal and vertical padding.
  ///
  /// Note: Non-const to allow variable parameters.
  /// For const usage, use the main constructor with [EdgeInsets.symmetric] directly.
  VPadding.symmetric({
    super.key,
    required this.child,
    double horizontal = 0.0,
    double vertical = 0.0,
    // Video timing
    this.startFrame,
    this.endFrame,
    this.fadeInFrames = VideoTimingDefaults.fadeInFrames,
    this.fadeOutFrames = VideoTimingDefaults.fadeOutFrames,
    this.fadeInCurve = VideoTimingDefaults.fadeInCurve,
    this.fadeOutCurve = VideoTimingDefaults.fadeOutCurve,
  }) : padding = EdgeInsets.symmetric(
         horizontal: horizontal,
         vertical: vertical,
       );

  /// Creates a video-aware Padding with only the given values non-zero.
  ///
  /// Note: Non-const to allow variable parameters.
  /// For const usage, use the main constructor with [EdgeInsets.only] directly.
  VPadding.only({
    super.key,
    required this.child,
    double left = 0.0,
    double top = 0.0,
    double right = 0.0,
    double bottom = 0.0,
    // Video timing
    this.startFrame,
    this.endFrame,
    this.fadeInFrames = VideoTimingDefaults.fadeInFrames,
    this.fadeOutFrames = VideoTimingDefaults.fadeOutFrames,
    this.fadeInCurve = VideoTimingDefaults.fadeInCurve,
    this.fadeOutCurve = VideoTimingDefaults.fadeOutCurve,
  }) : padding = EdgeInsets.only(
         left: left,
         top: top,
         right: right,
         bottom: bottom,
       );

  @override
  Widget build(BuildContext context) {
    final paddingWidget = Padding(padding: padding, child: child);

    return wrapWithTiming(paddingWidget);
  }
}
