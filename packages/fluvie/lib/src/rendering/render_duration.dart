/// The number of frames a render of [duration] at [fps] produces (at least one).
///
/// Throws an [ArgumentError] when [fps] or [duration] is not positive. A
/// sub-frame duration rounds up to a single frame.
int frameCountFor(Duration duration, int fps) {
  if (fps <= 0) throw ArgumentError.value(fps, 'fps', 'must be positive');
  if (duration <= Duration.zero) {
    throw ArgumentError.value(duration.toString(), 'duration', 'must be positive');
  }
  final frames = (duration.inMicroseconds * fps / Duration.microsecondsPerSecond).round();
  return frames < 1 ? 1 : frames;
}
