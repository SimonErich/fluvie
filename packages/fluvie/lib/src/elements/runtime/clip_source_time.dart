import 'package:fluvie_media/fluvie_media.dart' show MediaTimeline;

/// Converts a fractional source-picture coordinate into its display time.
/// The complete source end is the boundary after its final picture.
double sourceTimeForFrameOffset(MediaTimeline timeline, double offset) {
  if (offset <= 0) return 0;
  if (offset >= timeline.frameCount) return timeline.durationSeconds;
  final index = offset.floor();
  final start = timeline.timeForFrame(index);
  final end = index + 1 == timeline.frameCount
      ? timeline.durationSeconds
      : timeline.timeForFrame(index + 1);
  return start + (end - start) * (offset - index);
}

/// Converts an exact source time into a fractional picture coordinate.
double sourceFrameOffsetAt(MediaTimeline timeline, double seconds) {
  if (seconds <= 0) return 0;
  if (seconds >= timeline.durationSeconds) return timeline.frameCount.toDouble();
  final index = timeline.frameAt(seconds);
  final start = timeline.timeForFrame(index);
  final end = index + 1 == timeline.frameCount
      ? timeline.durationSeconds
      : timeline.timeForFrame(index + 1);
  return index + (seconds - start) / (end - start);
}
