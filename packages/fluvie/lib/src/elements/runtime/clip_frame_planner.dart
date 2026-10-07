import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/elements/runtime/clip_resampler.dart';
import 'package:fluvie/src/elements/runtime/clip_source_time.dart';
import 'package:fluvie_media/fluvie_media.dart' show MediaTimeline;

/// Plans the distinct source-video frames a `Clip` reads across its composition
/// window, sorted ascending. The clip pre-pass extracts exactly this set.
///
/// It walks every composition frame the element is alive ([windowStart] for
/// [windowLength] frames at [compFps]) through [resampleClipFrame] at [speed]
/// and collects the source frames it lands on. Because the resample rule floors and clamps,
/// a slow source under a fast composition repeats frames, so the planned set is
/// smaller than the window; a window that outlives the trimmed source ends on
/// the last frame. Returns an empty list for an empty window.
List<int> planClipFrames({
  required int windowStart,
  required int windowLength,
  required int compFps,
  required double srcFps,
  required int trimStartFrames,
  required int trimEndFrames,
  double trimStartOffsetFrames = 0,
  double trimEndOffsetFrames = 0,
  double speed = 1,
  List<double>? sourceTimeMap,
  MediaTimeline? timeline,
}) {
  final frames = <int>{};
  for (var i = 0; i < windowLength; i++) {
    frames.add(
      resampleClipFrame(
        compFrame: windowStart + i,
        windowStart: windowStart,
        compFps: compFps,
        srcFps: srcFps,
        trimStartFrames: trimStartFrames,
        trimEndFrames: trimEndFrames,
        trimStartOffsetFrames: trimStartOffsetFrames,
        trimEndOffsetFrames: trimEndOffsetFrames,
        speed: speed,
        sourceTimeMap: sourceTimeMap,
        timeline: timeline,
      ),
    );
  }
  return frames.toList()..sort();
}

/// Resolves [trim] into source-frame bounds for [meta], defaulting to the whole
/// source. Shared by the clip painter (per frame) and the pre-pass (planning),
/// so the frames extracted are exactly the frames the painter reads.
({int start, int end}) resolveClipTrimBounds(
  TimeRange? trim,
  ClipMetadata meta, {
  MediaTimeline? timeline,
}) {
  final offsets = resolveClipTrimOffsets(trim, meta, timeline: timeline);
  return (start: (offsets.start + 1e-9).floor(), end: (offsets.end - 1e-9).ceil());
}

/// Exact source-frame coordinates, retaining the fractional phase of a cut.
/// Audio divides these by metadata fps; picture uses floor/ceil extraction
/// bounds plus their subframe offsets. A razor therefore never resets phase.
({double start, double end}) resolveClipTrimOffsets(
  TimeRange? trim,
  ClipMetadata meta, {
  MediaTimeline? timeline,
}) {
  if (trim == null) return (start: 0, end: meta.frameCount.toDouble());
  if (timeline != null) {
    double resolve(Time time) => resolveSourceTimeSeconds(
      time,
      fps: meta.fps,
      durationFrames: timeline.frameCount,
      durationSeconds: timeline.durationSeconds,
      frameTime: (frame) => sourceTimeForFrameOffset(timeline, frame.toDouble()),
    );
    final start = resolve(trim.start);
    final end = resolve(trim.end);
    if (end < start) throw ArgumentError('Inverted source trim: $end seconds precedes $start');
    return (start: sourceFrameOffsetAt(timeline, start), end: sourceFrameOffsetAt(timeline, end));
  }
  final start = resolveSourceTimeOffset(trim.start, fps: meta.fps, durationFrames: meta.frameCount);
  final end = resolveSourceTimeOffset(trim.end, fps: meta.fps, durationFrames: meta.frameCount);
  if (end < start) throw ArgumentError('Inverted source trim: frame $end precedes $start');
  return (
    start: start.clamp(0, meta.frameCount.toDouble()),
    end: end.clamp(0, meta.frameCount.toDouble()),
  );
}
