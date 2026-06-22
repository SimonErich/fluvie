import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/elements/runtime/clip_resampler.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

/// Plans the distinct source-video frames a `Clip` reads across its composition
/// window, sorted ascending. The clip pre-pass extracts exactly this set.
///
/// It walks every composition frame the element is alive ([windowStart] for
/// [windowLength] frames at [compFps]) through [resampleClipFrame] and collects
/// the source frames it lands on. Because the resample rule floors and clamps,
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
      ),
    );
  }
  return frames.toList()..sort();
}

/// Resolves [trim] into source-frame bounds for [meta], defaulting to the whole
/// source. Shared by the clip painter (per frame) and the pre-pass (planning),
/// so the frames extracted are exactly the frames the painter reads.
({int start, int end}) resolveClipTrimBounds(TimeRange? trim, ClipMetadata meta) {
  if (trim == null) return (start: 0, end: meta.frameCount);
  final sourceScope = TimeScopeData(
    fps: meta.fps.round(),
    startFrame: 0,
    durationFrames: meta.frameCount,
  );
  return trim.resolveClamped(sourceScope, min: 0, max: meta.frameCount);
}
