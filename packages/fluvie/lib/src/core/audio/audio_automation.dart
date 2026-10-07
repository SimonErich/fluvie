import 'package:flutter/animation.dart' show Curve, Curves;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_scope.dart';
import 'package:meta/meta.dart';

/// An authored gain envelope using the shared values/positions/easings grammar.
/// Values are clamped to 0..1 at resolution; the separate track and lane gain
/// remain multipliers. Positions are relative to the track's audible window.
@immutable
final class AudioAutomation {
  /// Creates a volume envelope; absent/empty values mean no automation.
  const AudioAutomation({
    this.values = const [],
    this.positions = const [],
    this.easings = const [],
  });

  /// Gain multipliers in time order.
  final List<double> values;

  /// One authored time per value (or empty for a single constant value).
  final List<Time> positions;

  /// One curve per segment, or empty for linear interpolation.
  final List<Curve> easings;

  /// Whether this envelope leaves the static gain unchanged.
  bool get isEmpty => values.isEmpty;

  /// Resolves positions and curves into encoder-neutral seconds. Nonlinear
  /// curves are sampled at composition-frame boundaries; all encoders consume
  /// these same samples. Linear segments retain only their authored endpoints.
  List<AudioVolumePoint> resolve({required int fps, required int windowFrames}) {
    if (isEmpty) return const [];
    if (values.any((v) => !v.isFinite)) {
      throw ArgumentError('Volume values must be finite');
    }
    if (values.length == 1) return [AudioVolumePoint(0, values.single.clamp(0.0, 1.0))];
    if (positions.length != values.length ||
        (easings.isNotEmpty && easings.length != values.length - 1)) {
      throw ArgumentError('Automation needs one position per value and one easing per segment');
    }
    final scope = _AutomationScope(fps, windowFrames);
    final frames = [for (final position in positions) position.resolveFrames(scope)];
    for (var i = 1; i < frames.length; i++) {
      if (frames[i] <= frames[i - 1]) {
        throw ArgumentError('Automation positions must strictly increase');
      }
    }
    final result = <AudioVolumePoint>[];
    for (var i = 0; i < values.length - 1; i++) {
      final curve = easings.isEmpty ? Curves.linear : easings[i];
      final from = frames[i];
      final to = frames[i + 1];
      final samples = curve == Curves.linear ? [from] : [for (var f = from; f < to; f++) f];
      for (final frame in samples) {
        final eased = curve.transform((frame - from) / (to - from));
        result.add(
          AudioVolumePoint(
            frame / fps,
            (values[i] + (values[i + 1] - values[i]) * eased).clamp(0.0, 1.0),
          ),
        );
      }
    }
    result.add(AudioVolumePoint(frames.last / fps, values.last.clamp(0.0, 1.0)));
    return List.unmodifiable(result);
  }

  @override
  bool operator ==(Object other) =>
      other is AudioAutomation &&
      listEquals(values, other.values) &&
      listEquals(positions, other.positions) &&
      listEquals(easings, other.easings);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(values), Object.hashAll(positions), Object.hashAll(easings));
}

/// One sample in the resolved, piecewise-linear volume envelope.
@immutable
final class AudioVolumePoint {
  /// Time in seconds relative to the audible start, and linear gain multiplier.
  const AudioVolumePoint(this.seconds, this.value);

  /// Time from the audible start.
  final double seconds;

  /// Gain multiplier.
  final double value;
}

/// Evaluates the same envelope consumed by every encoder and editor meter.
double audioVolumeAt(List<AudioVolumePoint> points, double seconds) {
  if (points.isEmpty) return 1;
  if (seconds <= points.first.seconds) return points.first.value;
  if (seconds >= points.last.seconds) return points.last.value;
  var low = 0;
  var high = points.length - 1;
  while (high - low > 1) {
    final mid = (high + low) ~/ 2;
    if (points[mid].seconds <= seconds) {
      low = mid;
    } else {
      high = mid;
    }
  }
  final a = points[low];
  final b = points[high];
  return a.value + (b.value - a.value) * (seconds - a.seconds) / (b.seconds - a.seconds);
}

final class _AutomationScope implements TimeScope {
  const _AutomationScope(this.fps, this.durationFrames);
  @override
  final int fps;
  @override
  final int durationFrames;
  @override
  int get startFrame => 0;
  @override
  TimeScope? get parent => null;
}
