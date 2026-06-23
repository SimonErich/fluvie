import 'package:flutter/widgets.dart' show Widget;
import 'package:fluvie/src/composition/runtime/media_collector.dart' show collectClipPlans;
import 'package:fluvie/src/core/contracts/clip_frame_preparer.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/elements/runtime/clip_frame_planner.dart';
import 'package:fluvie/src/rendering/collect_composition_media.dart';

/// Pre-resolves every clip in [composition] before the frame loop: probe each
/// for its [ClipMetadata], plan the source frames it reads, and extract them
/// through [resolver]. A no-op when the composition declares no clips or wraps no
/// `Video`.
///
/// Capture is synchronous, so a clip cannot decode mid-frame: its frames must be
/// extracted up front. Run this after `preResolveAll` (a clip source is
/// content-hashed there first). Planning uses the video's own fps, the same clock
/// the painter resamples against.
///
/// Planning covers each clip from its scene start through the **end of the
/// composition** ([totalFrames]), not just its own scene window: a `Clip` painter
/// rebuilds on every composition frame, and outside its window the resampler
/// clamps to the clip's first or last source frame. So a clip in an early scene
/// is still painted (held on its last frame) while later scenes are on screen,
/// and that clamped frame must be extracted too. The resampler dedupes, so the
/// planned set stays the in-window frames plus those boundary frames.
///
/// A [resolver] that streams clip frames (implements [ClipFramePreparer]) also
/// gets each clip's scene-relative plan registered here, so the capture loop's
/// per-frame `prepareClipFrames` can decode just the window each frame needs
/// rather than every frame at once.
Future<void> preResolveCompositionClips({
  required Widget composition,
  required MediaResolver resolver,
  required int totalFrames,
}) async {
  final video = compositionVideo(composition);
  if (video == null) return;
  final fps = video.fps;
  final preparer = resolver is ClipFramePreparer ? resolver as ClipFramePreparer : null;
  for (final plan in collectClipPlans(video.scenes, fps)) {
    final meta = await resolver.probeClip(plan.source);
    final bounds = resolveClipTrimBounds(plan.trim, meta);
    final frames = planClipFrames(
      windowStart: 0,
      // From the clip's scene start to the composition end, so the frames it is
      // clamped to while painting off-screen in later scenes are extracted too.
      windowLength: totalFrames - plan.windowStart,
      compFps: fps,
      srcFps: meta.fps,
      trimStartFrames: bounds.start,
      trimEndFrames: bounds.end,
    );
    if (frames.isEmpty) continue;
    preparer?.registerClipPlan(
      source: plan.source,
      windowStart: plan.windowStart,
      windowLength: plan.windowLength,
      compFps: fps,
      trimStartFrames: bounds.start,
      trimEndFrames: bounds.end,
    );
    await resolver.preResolveClip(plan.source, frames);
  }
}
