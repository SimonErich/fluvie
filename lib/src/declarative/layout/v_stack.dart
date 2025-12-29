import 'package:flutter/widgets.dart';
import 'video_timing_mixin.dart';

/// A video-aware Stack widget with timing and fade properties.
///
/// [VStack] extends Flutter's [Stack] with video-specific properties like
/// startFrame, endFrame, and fade transitions. It automatically wraps itself
/// in a [Layer] when video timing is configured.
///
/// Example:
/// ```dart
/// VStack(
///   startFrame: 30,
///   endFrame: 120,
///   fadeInFrames: 15,
///   fadeOutFrames: 15,
///   alignment: Alignment.center,
///   children: [
///     Background(),
///     Content(),
///   ],
/// )
/// ```
class VStack extends StatelessWidget with VideoTimingMixin {
  /// The widgets below this widget in the tree.
  final List<Widget> children;

  /// How to align the non-positioned and partially-positioned children in the
  /// stack.
  final AlignmentGeometry alignment;

  /// How to size the non-positioned children in the stack.
  final StackFit fit;

  /// The text direction to use for alignment.
  final TextDirection? textDirection;

  /// Whether overflowing children should be clipped.
  final Clip clipBehavior;

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

  /// Creates a video-aware Stack.
  const VStack({
    super.key,
    this.children = const <Widget>[],
    this.alignment = AlignmentDirectional.topStart,
    this.fit = StackFit.loose,
    this.textDirection,
    this.clipBehavior = Clip.hardEdge,
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
    final stack = Stack(
      alignment: alignment,
      fit: fit,
      textDirection: textDirection,
      clipBehavior: clipBehavior,
      children: children,
    );

    return wrapWithTiming(stack);
  }
}
