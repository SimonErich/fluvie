import 'package:flutter/widgets.dart' show Widget;
import 'package:fluvie/src/composition/runtime/media_collector.dart' show collectClipPlans;
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/elements/runtime/clip_frame_planner.dart';
import 'package:fluvie/src/rendering/collect_composition_media.dart';

/// Pre-resolves every clip in [composition] before the frame loop: probe each
/// for its [ClipMetadata], plan the source frames its scene window reads, and
/// extract them through [resolver]. A no-op when the composition declares no
/// clips or wraps no `Video`.
///
/// Capture is synchronous, so a clip cannot decode mid-frame: its frames must be
/// extracted up front. Run this after `preResolveAll` (a clip source is
/// content-hashed there first), so the painter's `decodedClipFrame` lookup is a
/// warm cache hit for every frame the resampler can land on. Planning uses the
/// video's own fps, the same clock the painter resamples against, and covers the
/// whole scene window — the longest a clip can play — so a nested time scope
/// only ever reads a subset of the extracted frames.
Future<void> preResolveCompositionClips({
  required Widget composition,
  required MediaResolver resolver,
}) async {
  final video = compositionVideo(composition);
  if (video == null) return;
  final fps = video.fps;
  for (final plan in collectClipPlans(video.scenes, fps)) {
    final meta = await resolver.probeClip(plan.source);
    final bounds = resolveClipTrimBounds(plan.trim, meta);
    final frames = planClipFrames(
      windowStart: 0,
      windowLength: plan.windowLength,
      compFps: fps,
      srcFps: meta.fps,
      trimStartFrames: bounds.start,
      trimEndFrames: bounds.end,
    );
    if (frames.isNotEmpty) await resolver.preResolveClip(plan.source, frames);
  }
}
