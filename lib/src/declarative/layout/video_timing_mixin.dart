import 'package:flutter/widgets.dart';
import '../../presentation/layer.dart';

/// A mixin that provides common video timing properties for layout widgets.
///
/// This mixin adds video-specific properties like startFrame, endFrame,
/// and fade transitions to any widget, making it video-aware.
mixin VideoTimingMixin {
  /// Frame at which this widget becomes visible (inclusive).
  int? get startFrame;

  /// Frame at which this widget becomes invisible (exclusive).
  int? get endFrame;

  /// Duration of fade-in transition in frames.
  int get fadeInFrames;

  /// Duration of fade-out transition in frames.
  int get fadeOutFrames;

  /// Curve for fade-in animation.
  Curve get fadeInCurve;

  /// Curve for fade-out animation.
  Curve get fadeOutCurve;

  /// Whether video timing is enabled (any timing property is set).
  bool get hasVideoTiming =>
      startFrame != null ||
      endFrame != null ||
      fadeInFrames > 0 ||
      fadeOutFrames > 0;

  /// Wraps a child widget with video timing if enabled.
  ///
  /// If no video timing properties are set, returns the child unchanged.
  Widget wrapWithTiming(Widget child) {
    if (!hasVideoTiming) {
      return child;
    }

    return Layer(
      startFrame: startFrame,
      endFrame: endFrame,
      fadeInFrames: fadeInFrames,
      fadeOutFrames: fadeOutFrames,
      fadeInCurve: fadeInCurve,
      fadeOutCurve: fadeOutCurve,
      child: child,
    );
  }
}

/// Default values for video timing properties.
class VideoTimingDefaults {
  VideoTimingDefaults._();

  static const int fadeInFrames = 0;
  static const int fadeOutFrames = 0;
  static const Curve fadeInCurve = Curves.easeOut;
  static const Curve fadeOutCurve = Curves.easeIn;
}
