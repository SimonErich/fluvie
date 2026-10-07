part of 'time.dart';

/// A [Time] expressed as an exact number of frames, independent of fps.
final class FrameTime extends Time {
  /// Creates a time of exactly [frames] frames.
  const FrameTime(this.frames);

  /// The frame count this time resolves to in any scope.
  final int frames;

  @override
  int resolveFrames(TimeScope scope) => frames;

  @override
  bool operator ==(Object other) => other is FrameTime && other.frames == frames;

  @override
  int get hashCode => Object.hash(FrameTime, frames);

  @override
  String toString() => 'Time.frames($frames)';
}
