import 'dart:math' as math;

/// Maps a composition frame to the source-video frame a `Clip` reads — the
/// deterministic floor-resampling rule.
///
/// The element is alive over a window that starts at [windowStart] (its
/// resolved scene-relative start frame) in composition space, playing at
/// [compFps]. The source video runs at [srcFps], and the clip's trim begins
/// at [trimStartFrames] and ends just before [trimEndFrames] (both in *source*
/// frame space).
///
/// ```text
/// elapsed  = compFrame - windowStart                 // composition frames in
/// advanced = floor(elapsed / compFps * srcFps)       // source frames advanced
/// srcFrame = (advanced + trimStartFrames)
///              .clamp(trimStartFrames, trimEndFrames - 1)
/// ```
///
/// `floor` (not `round`) is deliberate: a held frame never reads *past* its
/// window, so a slow source under a fast composition repeats frames instead of
/// skipping ahead. The clamp keeps both trim bounds exact — a frame before the
/// window reads the trim start, and a window that outlives the trimmed source
/// holds its last frame (`trimEndFrames - 1`). The function is pure, so two
/// renders of the same composition resample identically.
int resampleClipFrame({
  required int compFrame,
  required int windowStart,
  required int compFps,
  required double srcFps,
  required int trimStartFrames,
  required int trimEndFrames,
}) {
  final elapsed = compFrame - windowStart;
  final advanced = (elapsed / compFps * srcFps).floor();
  final raw = advanced + trimStartFrames;
  final lastFrame = trimEndFrames - 1;
  return math.max(trimStartFrames, math.min(raw, lastFrame));
}
