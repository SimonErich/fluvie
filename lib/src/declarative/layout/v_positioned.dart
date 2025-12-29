import 'package:flutter/widgets.dart';
import 'video_timing_mixin.dart';

/// A video-aware Positioned widget with timing, fade, and animation properties.
///
/// [VPositioned] extends Flutter's [Positioned] with video-specific properties
/// like startFrame, endFrame, fade transitions, entry/exit animations, and
/// hero transitions (via GlobalKey).
///
/// Example:
/// ```dart
/// VStack(
///   children: [
///     VPositioned(
///       left: 100,
///       top: 200,
///       startFrame: 30,
///       fadeInFrames: 15,
///       heroKey: myKey,  // For automatic cross-scene transitions
///       child: Image.asset('photo.jpg'),
///     ),
///   ],
/// )
/// ```
class VPositioned extends StatelessWidget with VideoTimingMixin {
  /// The child widget.
  final Widget child;

  /// The distance that the child's left edge is inset from the left of the stack.
  final double? left;

  /// The distance that the child's top edge is inset from the top of the stack.
  final double? top;

  /// The distance that the child's right edge is inset from the right of the stack.
  final double? right;

  /// The distance that the child's bottom edge is inset from the bottom of the stack.
  final double? bottom;

  /// The child's width.
  final double? width;

  /// The child's height.
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

  /// A GlobalKey for hero-style transitions between scenes.
  ///
  /// When two VPositioned widgets in adjacent scenes share the same heroKey,
  /// the Video widget will automatically animate between their positions
  /// during scene transitions.
  final GlobalKey? heroKey;

  /// Creates a video-aware Positioned widget.
  const VPositioned({
    super.key,
    required this.child,
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.width,
    this.height,
    // Video timing
    this.startFrame,
    this.endFrame,
    this.fadeInFrames = VideoTimingDefaults.fadeInFrames,
    this.fadeOutFrames = VideoTimingDefaults.fadeOutFrames,
    this.fadeInCurve = VideoTimingDefaults.fadeInCurve,
    this.fadeOutCurve = VideoTimingDefaults.fadeOutCurve,
    // Hero transitions
    this.heroKey,
  });

  /// Creates a VPositioned that fills the entire Stack.
  const VPositioned.fill({
    super.key,
    required this.child,
    this.left = 0.0,
    this.top = 0.0,
    this.right = 0.0,
    this.bottom = 0.0,
    // Video timing
    this.startFrame,
    this.endFrame,
    this.fadeInFrames = VideoTimingDefaults.fadeInFrames,
    this.fadeOutFrames = VideoTimingDefaults.fadeOutFrames,
    this.fadeInCurve = VideoTimingDefaults.fadeInCurve,
    this.fadeOutCurve = VideoTimingDefaults.fadeOutCurve,
    this.heroKey,
  }) : width = null,
       height = null;

  /// Creates a VPositioned from an Offset.
  VPositioned.fromOffset({
    super.key,
    required this.child,
    required Offset offset,
    this.width,
    this.height,
    // Video timing
    this.startFrame,
    this.endFrame,
    this.fadeInFrames = VideoTimingDefaults.fadeInFrames,
    this.fadeOutFrames = VideoTimingDefaults.fadeOutFrames,
    this.fadeInCurve = VideoTimingDefaults.fadeInCurve,
    this.fadeOutCurve = VideoTimingDefaults.fadeOutCurve,
    this.heroKey,
  }) : left = offset.dx,
       top = offset.dy,
       right = null,
       bottom = null;

  /// Creates a VPositioned from a Rect.
  VPositioned.fromRect({
    super.key,
    required this.child,
    required Rect rect,
    // Video timing
    this.startFrame,
    this.endFrame,
    this.fadeInFrames = VideoTimingDefaults.fadeInFrames,
    this.fadeOutFrames = VideoTimingDefaults.fadeOutFrames,
    this.fadeInCurve = VideoTimingDefaults.fadeInCurve,
    this.fadeOutCurve = VideoTimingDefaults.fadeOutCurve,
    this.heroKey,
  }) : left = rect.left,
       top = rect.top,
       width = rect.width,
       height = rect.height,
       right = null,
       bottom = null;

  @override
  Widget build(BuildContext context) {
    Widget result = Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      width: width,
      height: height,
      child: child,
    );

    // If heroKey is set, wrap with KeyedSubtree for identification
    if (heroKey != null) {
      result = KeyedSubtree(key: heroKey, child: result);
    }

    return wrapWithTiming(result);
  }
}
