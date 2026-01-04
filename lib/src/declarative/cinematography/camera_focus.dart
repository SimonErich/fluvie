import 'package:flutter/widgets.dart';

import '../../presentation/time_consumer.dart';

/// A widget that applies camera-like transformations to its child.
///
/// [CameraFocus] provides zoom, pan, and rotation effects using keyframes.
/// This creates cinematic camera movements over time.
///
/// Example:
/// ```dart
/// CameraFocus(
///   zoomKeyframes: {0: 1.0, 60: 1.5, 120: 1.0},
///   positionKeyframes: {0: Offset.zero, 60: Offset(100, 50)},
///   child: MyContent(),
/// )
/// ```
class CameraFocus extends StatelessWidget {
  /// The child widget to transform.
  final Widget child;

  /// Keyframes for zoom level (frame -> scale).
  final Map<int, double>? zoomKeyframes;

  /// Keyframes for camera position (frame -> offset).
  final Map<int, Offset>? positionKeyframes;

  /// Keyframes for rotation (frame -> radians).
  final Map<int, double>? rotationKeyframes;

  /// Alignment point for transformations.
  final Alignment alignment;

  /// Easing curve applied between keyframes.
  final Curve curve;

  /// Creates a camera focus widget.
  const CameraFocus({
    super.key,
    required this.child,
    this.zoomKeyframes,
    this.positionKeyframes,
    this.rotationKeyframes,
    this.alignment = Alignment.center,
    this.curve = Curves.easeInOut,
  });

  /// Creates a simple zoom effect.
  ///
  /// ```dart
  /// CameraFocus.zoom(
  ///   startZoom: 1.0,
  ///   endZoom: 1.5,
  ///   startFrame: 0,
  ///   endFrame: 60,
  ///   child: MyContent(),
  /// )
  /// ```
  CameraFocus.zoom({
    super.key,
    required this.child,
    required double startZoom,
    required double endZoom,
    required int startFrame,
    required int endFrame,
    this.alignment = Alignment.center,
    this.curve = Curves.easeInOut,
  })  : zoomKeyframes = {startFrame: startZoom, endFrame: endZoom},
        positionKeyframes = null,
        rotationKeyframes = null;

  /// Creates a simple pan effect.
  ///
  /// ```dart
  /// CameraFocus.pan(
  ///   startPosition: Offset.zero,
  ///   endPosition: Offset(100, 50),
  ///   startFrame: 0,
  ///   endFrame: 60,
  ///   child: MyContent(),
  /// )
  /// ```
  CameraFocus.pan({
    super.key,
    required this.child,
    required Offset startPosition,
    required Offset endPosition,
    required int startFrame,
    required int endFrame,
    this.alignment = Alignment.center,
    this.curve = Curves.easeInOut,
  })  : zoomKeyframes = null,
        positionKeyframes = {startFrame: startPosition, endFrame: endPosition},
        rotationKeyframes = null;

  @override
  Widget build(BuildContext context) {
    return TimeConsumer(
      builder: (context, frame, _) {
        // Calculate current values
        final zoom = _getZoom(frame);
        final position = _getPosition(frame);
        final rotation = _getRotation(frame);

        // Build transform matrix
        Widget result = child;

        // Apply rotation
        if (rotation != 0) {
          result = Transform.rotate(
            angle: rotation,
            alignment: alignment,
            child: result,
          );
        }

        // Apply zoom
        if (zoom != 1.0) {
          result = Transform.scale(
            scale: zoom,
            alignment: alignment,
            child: result,
          );
        }

        // Apply position
        if (position != Offset.zero) {
          result = Transform.translate(offset: position, child: result);
        }

        return result;
      },
    );
  }

  double _getZoom(int frame) {
    if (zoomKeyframes == null || zoomKeyframes!.isEmpty) return 1.0;
    return _interpolateKeyframes(frame, zoomKeyframes!);
  }

  Offset _getPosition(int frame) {
    if (positionKeyframes == null || positionKeyframes!.isEmpty) {
      return Offset.zero;
    }
    return _interpolateOffsetKeyframes(frame, positionKeyframes!);
  }

  double _getRotation(int frame) {
    if (rotationKeyframes == null || rotationKeyframes!.isEmpty) return 0.0;
    return _interpolateKeyframes(frame, rotationKeyframes!);
  }

  double _interpolateValue(
    int frame,
    int startFrame,
    int endFrame,
    double startValue,
    double endValue,
  ) {
    final progress = _getProgress(frame, startFrame, endFrame);
    return startValue + (endValue - startValue) * progress;
  }

  double _getProgress(int frame, int startFrame, int endFrame) {
    if (frame <= startFrame) return 0.0;
    if (frame >= endFrame) return 1.0;
    final linear = (frame - startFrame) / (endFrame - startFrame);
    return curve.transform(linear);
  }

  double _interpolateKeyframes(int frame, Map<int, double> keyframes) {
    final sortedFrames = keyframes.keys.toList()..sort();

    if (frame <= sortedFrames.first) return keyframes[sortedFrames.first]!;
    if (frame >= sortedFrames.last) return keyframes[sortedFrames.last]!;

    // Find surrounding keyframes
    int startFrame = sortedFrames.first;
    int endFrame = sortedFrames.last;

    for (int i = 0; i < sortedFrames.length - 1; i++) {
      if (frame >= sortedFrames[i] && frame <= sortedFrames[i + 1]) {
        startFrame = sortedFrames[i];
        endFrame = sortedFrames[i + 1];
        break;
      }
    }

    final startValue = keyframes[startFrame]!;
    final endValue = keyframes[endFrame]!;
    return _interpolateValue(frame, startFrame, endFrame, startValue, endValue);
  }

  Offset _interpolateOffsetKeyframes(int frame, Map<int, Offset> keyframes) {
    final sortedFrames = keyframes.keys.toList()..sort();

    if (frame <= sortedFrames.first) return keyframes[sortedFrames.first]!;
    if (frame >= sortedFrames.last) return keyframes[sortedFrames.last]!;

    // Find surrounding keyframes
    int startFrame = sortedFrames.first;
    int endFrame = sortedFrames.last;

    for (int i = 0; i < sortedFrames.length - 1; i++) {
      if (frame >= sortedFrames[i] && frame <= sortedFrames[i + 1]) {
        startFrame = sortedFrames[i];
        endFrame = sortedFrames[i + 1];
        break;
      }
    }

    final startValue = keyframes[startFrame]!;
    final endValue = keyframes[endFrame]!;
    final progress = _getProgress(frame, startFrame, endFrame);
    return Offset.lerp(startValue, endValue, progress)!;
  }
}
