import 'package:flutter/widgets.dart';
import '../../presentation/fade_container.dart';
import '../../presentation/time_consumer.dart';

/// An animated gradient widget that interpolates between keyframe colors.
///
/// [AnimatedGradient] allows you to define color keyframes and smoothly
/// animate between them based on the current frame.
///
/// Example:
/// ```dart
/// AnimatedGradient(
///   startColors: {0: Colors.red, 60: Colors.blue},
///   endColors: {0: Colors.orange, 60: Colors.purple},
///   type: GradientType.linear,
/// )
/// ```
class AnimatedGradient extends StatelessWidget {
  /// Start colors for the gradient at each keyframe.
  final Map<int, Color> startColors;

  /// End colors for the gradient at each keyframe.
  final Map<int, Color> endColors;

  /// The type of gradient.
  final AnimatedGradientType type;

  /// Start alignment for linear gradient.
  final Alignment begin;

  /// End alignment for linear gradient.
  final Alignment end;

  /// Center keyframes for radial gradient (frame -> alignment).
  final Map<int, Alignment>? centerKeyframes;

  /// Radius for radial gradient.
  final double radius;

  const AnimatedGradient({
    super.key,
    required this.startColors,
    required this.endColors,
    this.type = AnimatedGradientType.linear,
    this.begin = Alignment.topCenter,
    this.end = Alignment.bottomCenter,
    this.centerKeyframes,
    this.radius = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    return TimeConsumer(
      builder: (context, frame, progress) {
        final startColor = _interpolateColor(frame, startColors);
        final endColor = _interpolateColor(frame, endColors);
        final center = _interpolateAlignment(frame);

        return _buildGradient(startColor, endColor, center);
      },
    );
  }

  Color _interpolateColor(int frame, Map<int, Color> colors) {
    if (colors.isEmpty) return const Color(0xFF000000);
    if (colors.length == 1) return colors.values.first;

    final sortedFrames = colors.keys.toList()..sort();

    // Before first keyframe
    if (frame <= sortedFrames.first) {
      return colors[sortedFrames.first]!;
    }

    // After last keyframe
    if (frame >= sortedFrames.last) {
      return colors[sortedFrames.last]!;
    }

    // Find surrounding keyframes and interpolate
    for (int i = 0; i < sortedFrames.length - 1; i++) {
      if (frame >= sortedFrames[i] && frame <= sortedFrames[i + 1]) {
        final t =
            (frame - sortedFrames[i]) / (sortedFrames[i + 1] - sortedFrames[i]);
        return Color.lerp(
          colors[sortedFrames[i]],
          colors[sortedFrames[i + 1]],
          t,
        )!;
      }
    }

    return colors[sortedFrames.last]!;
  }

  Alignment _interpolateAlignment(int frame) {
    if (centerKeyframes == null || centerKeyframes!.isEmpty) {
      return Alignment.center;
    }

    final sortedFrames = centerKeyframes!.keys.toList()..sort();

    // Before first keyframe
    if (frame <= sortedFrames.first) {
      return centerKeyframes![sortedFrames.first]!;
    }

    // After last keyframe
    if (frame >= sortedFrames.last) {
      return centerKeyframes![sortedFrames.last]!;
    }

    // Find surrounding keyframes and interpolate
    for (int i = 0; i < sortedFrames.length - 1; i++) {
      if (frame >= sortedFrames[i] && frame <= sortedFrames[i + 1]) {
        final t =
            (frame - sortedFrames[i]) / (sortedFrames[i + 1] - sortedFrames[i]);
        return Alignment.lerp(
          centerKeyframes![sortedFrames[i]],
          centerKeyframes![sortedFrames[i + 1]],
          t,
        )!;
      }
    }

    return centerKeyframes![sortedFrames.last]!;
  }

  Widget _buildGradient(Color startColor, Color endColor, Alignment center) {
    switch (type) {
      case AnimatedGradientType.linear:
        return FadeContainer(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: begin,
              end: end,
              colors: [startColor, endColor],
            ),
          ),
        );
      case AnimatedGradientType.radial:
        return FadeContainer(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: center,
              radius: radius,
              colors: [startColor, endColor],
            ),
          ),
        );
      case AnimatedGradientType.sweep:
        return FadeContainer(
          decoration: BoxDecoration(
            gradient: SweepGradient(
              center: center,
              colors: [startColor, endColor, startColor],
            ),
          ),
        );
    }
  }
}

/// Type of animated gradient.
enum AnimatedGradientType { linear, radial, sweep }
