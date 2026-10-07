import 'dart:math' as math;

import 'package:flutter/widgets.dart' show Widget;
import 'package:fluvie/src/composition/runtime/clip_plan_collector.dart' show collectClipPlans;
import 'package:fluvie/src/core/contracts/clip_frame_preparer.dart';
import 'package:fluvie/src/core/contracts/clip_timeline_resolver.dart';
import 'package:fluvie/src/core/contracts/generative_resolver.dart';
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
/// Planning covers each clip from its own window start through the **end of the
/// composition** ([totalFrames]), not just the window itself: a `Clip` painter
/// rebuilds on every composition frame (a hidden scene still builds, and an
/// element outside its window is faded, never unmounted), and outside its window
/// the resampler clamps to the clip's first or last source frame. So a clip in
/// an early scene is still painted (held on its last frame) while later scenes
/// are on screen, and that clamped frame must be extracted too. The resampler
/// dedupes, so the planned set stays the in-window frames plus those boundary
/// frames.
///
/// A [resolver] that streams clip frames (implements [ClipFramePreparer]) also
/// gets each clip's window registered here, so the capture loop's per-frame
/// `prepareClipFrames` can decode just the frame each composition frame needs
/// rather than every frame at once. That window has to be the element's, since
/// it is what `ClipPainter` resamples against.
Future<void> preResolveCompositionClips({
  required Widget composition,
  required MediaResolver resolver,
  required int totalFrames,
  GenerativeResolver? generative,
}) async {
  final video = compositionVideo(composition);
  if (video == null) return;
  final fps = video.fps;
  final preparer = resolver is ClipFramePreparer ? resolver as ClipFramePreparer : null;
  for (final plan in collectClipPlans(
    video.scenes,
    fps,
    sceneStartFrames: video.sceneStartFrames,
    generative: generative,
    overlays: video.overlays,
    totalFrames: video.totalFrames,
  )) {
    final meta = await resolver.probeClip(plan.source);
    final timeline = clipTimelineFor(resolver, plan.source);
    final bounds = resolveClipTrimBounds(plan.trim, meta, timeline: timeline);
    final offsets = resolveClipTrimOffsets(plan.trim, meta, timeline: timeline);
    final frames = planClipFrames(
      windowStart: 0,
      // From the clip's own window start to the composition end, so the frames
      // it is clamped to while painting off-screen later are extracted too.
      //
      // At least one frame, always: a show window that clamps to zero length at
      // a scene edge leaves the element alive but with no span, and its painter
      // still resolves a clamped source frame on every composition frame. Plan
      // nothing there and that lookup finds nothing extracted.
      windowLength: math.max(1, totalFrames - plan.windowStart),
      compFps: fps,
      srcFps: meta.fps,
      timeline: timeline,
      trimStartFrames: bounds.start,
      trimEndFrames: bounds.end,
      trimStartOffsetFrames: offsets.start - bounds.start,
      trimEndOffsetFrames: offsets.end - bounds.end,
      speed: plan.speed,
      sourceTimeMap: plan.sourceTimeMap,
    );
    if (frames.isEmpty) continue;
    preparer?.registerClipPlan(
      source: plan.source,
      windowStart: plan.windowStart,
      windowLength: plan.windowLength,
      compFps: fps,
      trimStartFrames: bounds.start,
      trimEndFrames: bounds.end,
      trimStartOffsetFrames: offsets.start - bounds.start,
      trimEndOffsetFrames: offsets.end - bounds.end,
      speed: plan.speed,
      sourceTimeMap: plan.sourceTimeMap,
    );
    await resolver.preResolveClip(plan.source, frames);
  }
}
