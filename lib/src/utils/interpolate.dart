import 'package:flutter/animation.dart';

/// Interpolates a value based on the current frame within input/output ranges.
///
/// This function performs piecewise linear interpolation between keyframes,
/// with optional easing curves for smooth animations.
///
/// [frame] - The current frame number to interpolate at.
/// [inputRange] - List of frame breakpoints (must be sorted ascending, length >= 2).
/// [outputRange] - Corresponding output values (must have same length as inputRange).
/// [extrapolate] - Whether to extrapolate beyond the range (default: clamp to bounds).
/// [curve] - Optional easing curve applied to each segment (default: linear).
///
/// Returns the interpolated value at the given frame.
///
/// Example:
/// ```dart
/// // Linear interpolation: frames 0-30 map to values 0.0-100.0
/// final value = interpolate(15, [0, 30], [0.0, 100.0]);
/// // value == 50.0
///
/// // Multi-segment: bounce back
/// final pos = interpolate(frame, [0, 30, 60], [0.0, 200.0, 100.0]);
///
/// // With easing curve
/// final opacity = interpolate(
///   frame,
///   [0, 30],
///   [0.0, 1.0],
///   curve: Curves.easeInOut,
/// );
/// ```
///
/// Throws [ArgumentError] if:
/// - inputRange and outputRange have different lengths
/// - inputRange has fewer than 2 elements
/// - inputRange is not sorted in ascending order
double interpolate(
  int frame,
  List<int> inputRange,
  List<double> outputRange, {
  bool extrapolate = false,
  Curve curve = Curves.linear,
}) {
  // Validate inputs
  if (inputRange.length != outputRange.length) {
    throw ArgumentError(
      'inputRange and outputRange must have the same length. '
      'Got ${inputRange.length} and ${outputRange.length}.',
    );
  }

  if (inputRange.length < 2) {
    throw ArgumentError(
      'inputRange must have at least 2 elements. Got ${inputRange.length}.',
    );
  }

  // Validate sorting
  for (int i = 0; i < inputRange.length - 1; i++) {
    if (inputRange[i] > inputRange[i + 1]) {
      throw ArgumentError(
        'inputRange must be sorted in ascending order. '
        'Found ${inputRange[i]} > ${inputRange[i + 1]} at index $i.',
      );
    }
  }

  // Handle before range
  if (frame <= inputRange.first) {
    if (extrapolate && inputRange.length >= 2) {
      return _extrapolateBefore(frame, inputRange, outputRange);
    }
    return outputRange.first;
  }

  // Handle after range
  if (frame >= inputRange.last) {
    if (extrapolate && inputRange.length >= 2) {
      return _extrapolateAfter(frame, inputRange, outputRange);
    }
    return outputRange.last;
  }

  // Find the segment containing the frame
  for (int i = 0; i < inputRange.length - 1; i++) {
    if (frame >= inputRange[i] && frame < inputRange[i + 1]) {
      // Calculate linear progress within segment (0.0 to 1.0)
      final segmentLength = inputRange[i + 1] - inputRange[i];
      final progress = (frame - inputRange[i]) / segmentLength;

      // Apply curve transformation
      final curvedProgress = curve.transform(progress.clamp(0.0, 1.0));

      // Interpolate between output values
      final startValue = outputRange[i];
      final endValue = outputRange[i + 1];
      return startValue + curvedProgress * (endValue - startValue);
    }
  }

  // Fallback (should not reach here)
  return outputRange.last;
}

/// Extrapolates linearly before the input range.
double _extrapolateBefore(
  int frame,
  List<int> inputRange,
  List<double> outputRange,
) {
  final x0 = inputRange[0];
  final x1 = inputRange[1];
  final y0 = outputRange[0];
  final y1 = outputRange[1];

  if (x1 == x0) return y0;

  final slope = (y1 - y0) / (x1 - x0);
  return y0 + slope * (frame - x0);
}

/// Extrapolates linearly after the input range.
double _extrapolateAfter(
  int frame,
  List<int> inputRange,
  List<double> outputRange,
) {
  final lastIdx = inputRange.length - 1;
  final x0 = inputRange[lastIdx - 1];
  final x1 = inputRange[lastIdx];
  final y0 = outputRange[lastIdx - 1];
  final y1 = outputRange[lastIdx];

  if (x1 == x0) return y1;

  final slope = (y1 - y0) / (x1 - x0);
  return y1 + slope * (frame - x1);
}

/// Interpolates between two values with an optional curve.
///
/// A simpler alternative to [interpolate] for single-segment animations.
///
/// [t] - Progress value from 0.0 to 1.0.
/// [begin] - Starting value.
/// [end] - Ending value.
/// [curve] - Optional easing curve (default: linear).
///
/// Example:
/// ```dart
/// final opacity = lerpValue(progress, 0.0, 1.0, curve: Curves.easeIn);
/// ```
double lerpValue(
  double t,
  double begin,
  double end, {
  Curve curve = Curves.linear,
}) {
  final curvedT = curve.transform(t.clamp(0.0, 1.0));
  return begin + curvedT * (end - begin);
}
