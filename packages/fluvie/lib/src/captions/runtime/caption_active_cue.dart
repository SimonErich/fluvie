import 'package:fluvie/src/core/captions/caption_cue.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

/// The cue active at [frame] in [cues], or `null` when [frame] sits in no cue
/// window.
///
/// A cue is active over `[start, end)` resolved against [scope] (the cue times
/// are absolute, from the start of the video, so they resolve at the root
/// scope). When windows overlap the last matching cue wins, matching the
/// caption-on-top reading order. Pure and deterministic.
CaptionCue? activeCue(List<CaptionCue> cues, {required int frame, required TimeScopeData scope}) {
  CaptionCue? active;
  for (final cue in cues) {
    final start = cue.start.resolveFrames(scope);
    final end = cue.end.resolveFrames(scope);
    if (frame >= start && frame < end) active = cue;
  }
  return active;
}
