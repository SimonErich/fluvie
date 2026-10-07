import 'dart:math' as math;
import 'package:fluvie/src/elements/runtime/clip_source_time.dart';
import 'package:fluvie_media/fluvie_media.dart' show MediaTimeline;

/// Maps a composition frame to the source-video frame a `Clip` reads — the
/// deterministic floor-resampling rule.
///
/// The element is alive over a window that starts at [windowStart] (its
/// resolved scene-relative start frame) in composition space, playing at
/// [compFps]. The source video runs at [srcFps], and the clip's trim begins
/// at [trimStartFrames] and ends just before [trimEndFrames] (both in *source*
/// frame space). [speed] retimes it: `2` reads two source frames per source
/// frame of elapsed time, `0.5` reads one every two, and a negative value plays
/// the trim backwards from its last frame.
///
/// ```text
/// elapsed  = compFrame - windowStart                       // composition frames in
/// advanced = floor(elapsed / compFps * srcFps * |speed|)   // source frames advanced
/// srcFrame = speed < 0 ? (trimEndFrames - 1 - advanced)    // backwards from the end
///                      : (advanced + trimStartFrames)      // forwards from the start
/// srcFrame = srcFrame.clamp(trimStartFrames, trimEndFrames - 1)
/// ```
///
/// `floor` (not `round`) is deliberate: a held frame never reads *past* its
/// window, so a slow source under a fast composition repeats frames instead of
/// skipping ahead. The clamp keeps both trim bounds exact — a frame before the
/// window reads the trim start (the trim *end* when reversed), and a window
/// that outlives the trimmed source holds its last frame. The function is pure,
/// so two renders of the same composition resample identically.
int resampleClipFrame({
  required int compFrame,
  required int windowStart,
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
  final elapsed = compFrame - windowStart;
  final sourceSeconds = sourceTimeMap == null
      ? elapsed / compFps * speed.abs()
      : sourceTimeMap[elapsed.clamp(0, sourceTimeMap.length - 1)];
  if (timeline != null) {
    final start = sourceTimeForFrameOffset(timeline, trimStartFrames + trimStartOffsetFrames);
    final end = sourceTimeForFrameOffset(timeline, trimEndFrames + trimEndOffsetFrames);
    final seconds = speed < 0 ? end - sourceSeconds - 1e-9 : start + sourceSeconds;
    final last = math.max(0, trimEndFrames - 1);
    return timeline.frameAt(seconds).clamp(math.min(trimStartFrames, last), last);
  }
  // Numeric integration may land infinitesimally below an exact source frame.
  final sourcePosition = sourceSeconds * srcFps;
  final lastFrame = math.max(0, trimEndFrames - 1);
  final firstFrame = math.min(trimStartFrames, lastFrame);
  // Reversed, the window opens on the trim's last frame and walks down; the
  // same clamp then holds it at the trim start once it has run out.
  final raw = speed < 0
      ? (trimEndFrames + trimEndOffsetFrames - sourcePosition - 1e-9).floor()
      : trimStartFrames + (trimStartOffsetFrames + sourcePosition + 1e-9).floor();
  return math.max(firstFrame, math.min(raw, lastFrame));
}
