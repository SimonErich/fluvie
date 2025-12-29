/// A utility class for representing and calculating frame ranges.
///
/// [FrameRange] simplifies working with time-based visibility and animations
/// by providing helper methods for checking containment, calculating progress,
/// and converting between different time representations.
///
/// Example:
/// ```dart
/// final range = FrameRange(30, 120);
/// print(range.duration); // 90
/// print(range.contains(50)); // true
/// print(range.progress(75)); // 0.5
///
/// // From duration
/// final intro = FrameRange.fromDuration(0, 90); // frames 0-90
///
/// // From seconds (at 30fps)
/// final scene = FrameRange.fromSeconds(30, 1.0, 5.0); // 1s to 5s
/// ```
class FrameRange {
  /// The starting frame (inclusive).
  final int start;

  /// The ending frame (exclusive).
  final int end;

  /// Creates a frame range from start to end.
  ///
  /// [start] is inclusive, [end] is exclusive.
  /// Throws [ArgumentError] if end <= start.
  const FrameRange(this.start, this.end)
    : assert(end > start, 'end must be greater than start');

  /// Creates a frame range from a start frame and duration.
  ///
  /// Example:
  /// ```dart
  /// final range = FrameRange.fromDuration(30, 60); // frames 30-90
  /// ```
  factory FrameRange.fromDuration(int start, int duration) {
    if (duration <= 0) {
      throw ArgumentError('duration must be positive, got $duration');
    }
    return FrameRange(start, start + duration);
  }

  /// Creates a frame range from seconds, given the fps.
  ///
  /// Example:
  /// ```dart
  /// // At 30fps: 1.0s = frame 30, 3.0s = frame 90
  /// final range = FrameRange.fromSeconds(30, 1.0, 3.0);
  /// print(range.start); // 30
  /// print(range.end); // 90
  /// ```
  factory FrameRange.fromSeconds(int fps, double startSec, double endSec) {
    if (fps <= 0) {
      throw ArgumentError('fps must be positive, got $fps');
    }
    if (endSec <= startSec) {
      throw ArgumentError('endSec must be greater than startSec');
    }
    return FrameRange((startSec * fps).round(), (endSec * fps).round());
  }

  /// Creates a frame range from a duration in seconds, starting at a frame.
  ///
  /// Example:
  /// ```dart
  /// // 2 seconds at 30fps starting at frame 60
  /// final range = FrameRange.fromSecondsDuration(30, 60, 2.0);
  /// print(range.end); // 120
  /// ```
  factory FrameRange.fromSecondsDuration(
    int fps,
    int startFrame,
    double durationSec,
  ) {
    if (fps <= 0) {
      throw ArgumentError('fps must be positive, got $fps');
    }
    if (durationSec <= 0) {
      throw ArgumentError('durationSec must be positive, got $durationSec');
    }
    return FrameRange(startFrame, startFrame + (durationSec * fps).round());
  }

  /// The duration of this range in frames.
  int get duration => end - start;

  /// Returns the duration in seconds for a given fps.
  double durationInSeconds(int fps) => duration / fps;

  /// Checks if the given [frame] is within this range.
  ///
  /// Returns true if [frame] >= [start] and [frame] < [end].
  bool contains(int frame) => frame >= start && frame < end;

  /// Calculates the progress (0.0 to 1.0) of [frame] within this range.
  ///
  /// - Returns 0.0 if frame < start
  /// - Returns 1.0 if frame >= end
  /// - Returns interpolated value between 0.0 and 1.0 otherwise
  ///
  /// Example:
  /// ```dart
  /// final range = FrameRange(0, 100);
  /// print(range.progress(-10)); // 0.0
  /// print(range.progress(0));   // 0.0
  /// print(range.progress(50));  // 0.5
  /// print(range.progress(100)); // 1.0
  /// print(range.progress(150)); // 1.0
  /// ```
  double progress(int frame) {
    if (frame <= start) return 0.0;
    if (frame >= end) return 1.0;
    return (frame - start) / duration;
  }

  /// Calculates clamped progress (always between 0.0 and 1.0).
  ///
  /// This is equivalent to [progress] but makes the clamping explicit.
  double clampedProgress(int frame) => progress(frame).clamp(0.0, 1.0);

  /// Calculates unclamped progress (can be < 0 or > 1).
  ///
  /// Useful for extrapolation effects.
  double unclampedProgress(int frame) => (frame - start) / duration;

  /// Returns a new range offset by [frames].
  ///
  /// Example:
  /// ```dart
  /// final range = FrameRange(0, 100);
  /// final shifted = range.offset(50); // FrameRange(50, 150)
  /// ```
  FrameRange offset(int frames) => FrameRange(start + frames, end + frames);

  /// Returns a new range with start shifted by [frames].
  FrameRange shiftStart(int frames) => FrameRange(start + frames, end);

  /// Returns a new range with end shifted by [frames].
  FrameRange shiftEnd(int frames) => FrameRange(start, end + frames);

  /// Returns a new range expanded by [frames] on both sides.
  FrameRange expand(int frames) => FrameRange(start - frames, end + frames);

  /// Returns a new range contracted by [frames] on both sides.
  FrameRange contract(int frames) {
    final newStart = start + frames;
    final newEnd = end - frames;
    if (newEnd <= newStart) {
      throw ArgumentError('Cannot contract range by $frames frames');
    }
    return FrameRange(newStart, newEnd);
  }

  /// Checks if this range overlaps with [other].
  bool overlaps(FrameRange other) => start < other.end && end > other.start;

  /// Returns the intersection of this range with [other], or null if no overlap.
  FrameRange? intersection(FrameRange other) {
    if (!overlaps(other)) return null;
    final newStart = start > other.start ? start : other.start;
    final newEnd = end < other.end ? end : other.end;
    return FrameRange(newStart, newEnd);
  }

  /// Returns a range that covers both this and [other].
  FrameRange union(FrameRange other) {
    final newStart = start < other.start ? start : other.start;
    final newEnd = end > other.end ? end : other.end;
    return FrameRange(newStart, newEnd);
  }

  /// Splits this range at [frame], returning two ranges.
  ///
  /// Returns null if [frame] is not within the range.
  (FrameRange, FrameRange)? splitAt(int frame) {
    if (frame <= start || frame >= end) return null;
    return (FrameRange(start, frame), FrameRange(frame, end));
  }

  /// Returns [count] evenly spaced frames within this range.
  ///
  /// Useful for keyframe generation.
  List<int> keyframes(int count) {
    if (count < 2) {
      throw ArgumentError('count must be at least 2, got $count');
    }
    final step = duration / (count - 1);
    return List.generate(count, (i) => start + (step * i).round());
  }

  /// Converts a local frame (0-based within range) to global frame.
  int localToGlobal(int localFrame) => start + localFrame;

  /// Converts a global frame to local frame (0-based within range).
  ///
  /// Returns negative if frame is before start.
  int globalToLocal(int globalFrame) => globalFrame - start;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FrameRange &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'FrameRange($start, $end)';
}
