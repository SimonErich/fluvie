import 'dart:math' as math;

import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/elements/runtime/clip_frame_planner.dart';
import 'package:fluvie/src/elements/runtime/clip_source_time.dart';
import 'package:fluvie_media/fluvie_media.dart' show MediaTimeline;

/// Resolves the source-time window a clip's embedded audio plays, in seconds.
///
/// Both bounds are **absolute times in the source file**, because that is what
/// `atrim=start=…:end=…` and `ResolvedAudioTrack.trimStartSeconds` mean. The
/// start is where the clip's [trim] opens; the end is the earlier of the trim's
/// own end and [windowFrames] later, so the audio stops when the clip stops
/// being shown and a sequential clip cannot bleed into the next one.
///
/// [speed] scales how much source time the window consumes; its sign is
/// irrelevant here, because a reversed clip contributes no audio at all.
///
/// An untrimmed clip needs no [meta]: it plays from the head of the file for
/// the length of its window. A trimmed clip does, because a relative trim
/// resolves against a scope built from the source's own fps and frame count
/// ([resolveClipTrimOffsets]) — the same resolution the painter uses, so the
/// audio opens on the frame the picture opens on. Passing no [meta] for a
/// trimmed clip is a [FluvieRenderException] naming [sourceLabel] rather than
/// a silent start at zero, which is what a desynced render sounds like.
({double start, double end}) resolveClipAudioTrimSeconds({
  required TimeRange? trim,
  required ClipMetadata? meta,
  required int windowFrames,
  required int fps,
  required String sourceLabel,
  double speed = 1,
  MediaTimeline? timeline,
}) {
  // A retimed clip spends source time faster or slower than composition time,
  // so the window it consumes scales with the rate: three composition seconds
  // at 2x read six seconds of source.
  final windowSeconds = windowFrames / fps * speed.abs();
  if (trim == null) return (start: 0, end: windowSeconds);
  if (meta == null) {
    throw FluvieRenderException(
      'The clip "$sourceLabel" is trimmed, so its audio cannot be placed '
      'without the probed source. Pass clipMetadata so the trim resolves '
      'against the source, or the audio would start at zero while the picture '
      'starts at the trim.',
    );
  }
  final bounds = resolveClipTrimOffsets(trim, meta, timeline: timeline);
  final start = timeline == null
      ? bounds.start / meta.fps
      : sourceTimeForFrameOffset(timeline, bounds.start);
  final end = timeline == null
      ? bounds.end / meta.fps
      : sourceTimeForFrameOffset(timeline, bounds.end);
  return (start: start, end: math.min(start + windowSeconds, end));
}
