import 'dart:math' as math;

import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_scope.dart';
import 'package:meta/meta.dart';

/// A window in time: a [start] and an [end], each a symbolic [Time].
///
/// Build one fluently with [TimeRangeX]: `3.seconds.to(8.seconds)`. Like
/// [Time], a range stays symbolic until it is resolved against a [TimeScope],
/// so the same range can resolve differently per scope (fps, window length).
///
/// The resolved range is half-open: [start] is inclusive, [end] is exclusive
/// (see [containsFrame]). A zero-length range is valid and contains no frame.
/// A range whose resolved end lands *before* its resolved start is invalid
/// and throws an [ArgumentError] at resolve time.
@immutable
final class TimeRange {
  /// Creates a range running from [start] to [end].
  const TimeRange(this.start, this.end);

  /// Where the range begins (inclusive once resolved).
  final Time start;

  /// Where the range ends (exclusive once resolved).
  final Time end;

  /// Resolves both endpoints to absolute frames within [scope].
  ///
  /// Throws an [ArgumentError] naming both endpoints when the resolved end
  /// lands before the resolved start — with mixed units this can happen at
  /// one fps and not another.
  ({int start, int end}) resolveFrames(TimeScope scope) {
    final startFrame = start.resolveFrames(scope);
    final endFrame = end.resolveFrames(scope);
    if (endFrame < startFrame) {
      throw ArgumentError(
        'Inverted TimeRange at ${scope.fps} fps: start $start resolves to frame $startFrame '
        'but end $end resolves to frame $endFrame (the end must not lie before the start).',
      );
    }
    return (start: startFrame, end: endFrame);
  }

  /// The resolved length of this range in frames (`end - start`); zero for a
  /// zero-length range. Throws like [resolveFrames] on an inverted range.
  int durationFrames(TimeScope scope) {
    final resolved = resolveFrames(scope);
    return resolved.end - resolved.start;
  }

  /// Whether [frame] lies inside the resolved range:
  /// `start <= frame < end`.
  bool containsFrame(int frame, TimeScope scope) {
    final resolved = resolveFrames(scope);
    return frame >= resolved.start && frame < resolved.end;
  }

  /// Resolves both endpoints, then clamps each into `min..max` (inclusive).
  ///
  /// This is the smallest clamping helper later layers need: an element
  /// window resolved against its scene is clamped into the scene's own frame
  /// span so it can never overhang. A range lying entirely outside the
  /// bounds collapses to a zero-length range at the nearest bound. Throws an
  /// [ArgumentError] when [max] is smaller than [min], or like
  /// [resolveFrames] when the range itself is inverted.
  ({int start, int end}) resolveClamped(TimeScope scope, {required int min, required int max}) {
    if (max < min) {
      throw ArgumentError('Invalid clamp bounds: min ($min) must not exceed max ($max).');
    }
    final resolved = resolveFrames(scope);
    return (start: _clamp(resolved.start, min, max), end: _clamp(resolved.end, min, max));
  }

  static int _clamp(int value, int min, int max) => math.max(min, math.min(value, max));

  @override
  String toString() => 'TimeRange($start to $end)';
}

/// Fluent [TimeRange] construction from a start [Time].
extension TimeRangeX on Time {
  /// A range running from this time to [end]: `3.seconds.to(8.seconds)`.
  TimeRange to(Time end) => TimeRange(this, end);
}
