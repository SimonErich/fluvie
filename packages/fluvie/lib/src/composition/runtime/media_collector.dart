import 'package:flutter/widgets.dart';
import 'package:fluvie/src/composition/runtime/scene_tree_walk.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/core/contracts/generative_resolver.dart';
import 'package:fluvie/src/core/media/clip_audio.dart';
import 'package:fluvie/src/core/media/clip_source_kind.dart';
import 'package:fluvie/src/core/media/generative_kind.dart';
import 'package:fluvie/src/core/media/media_carrier.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/media/snapshot_source.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/elements/clip.dart';
import 'package:fluvie/src/elements/generative_media.dart';
import 'package:fluvie/src/elements/snapshot/snapshot.dart';
import 'package:fluvie/src/timing/placement/scene_frame_resolver.dart';

/// Gathers every declared [MediaSource] from [scenes] before the frame loop —
/// a pure structural walk over the constructor data, with no mounting and no
/// async.
///
/// Pre-resolution must finish *before* the first frame is pumped, so media
/// cannot be collected by mounting and registering: this walks the same tree
/// the user wrote (each scene's `Background` and its declared children, and the
/// children of the common layout widgets) and reads each [MediaCarrier]'s
/// `mediaSource` straight off its constructor. `Image`, `Clip`, and
/// `Background.image`/`.video` are carriers; everything else is transparent.
///
/// This collector lives in the composition layer because it walks `Scene`
/// trees: composition legitimately depends on `media` and `core`, so the
/// dependency edge points one way (composition → media), not the other. The
/// result is a `Set`, so the same declaration across scenes resolves once (the
/// cache deduplicates by value equality). The render harness hands this set to
/// `MediaResolver.preResolveAll` before frame 0.
///
/// When a [generative] resolver is given (after its `generateAll` ran), a
/// `GenerativeMedia` of a visual kind folds in as its produced file-backed
/// `MediaSource`, so generated images and videos pre-resolve through the same
/// pass as hand-written `Image`/`Clip`.
Set<MediaSource> collectMediaSources(List<Scene> scenes, {GenerativeResolver? generative}) {
  final sources = <MediaSource>{};
  walkSceneTree(scenes, (widget) {
    if (widget is MediaCarrier) {
      final source = (widget as MediaCarrier).mediaSource;
      if (source != null) sources.add(source);
    } else if (generative != null && widget is GenerativeMedia && widget.source.isVisual) {
      sources.add(generative.mediaFor(widget.source));
    }
  });
  return sources;
}

/// Gathers every declared [SnapshotSource] from [scenes] before the frame loop
/// — the snapshot sibling of [collectMediaSources], walking the same tree with
/// no mounting and no async.
///
/// `Mermaid`, `WebView`, and `Html` are carriers whose `snapshotSource` is read
/// straight off the constructor (a computed snapshot, not a loaded media), so
/// the render harness can hand the result to `MediaResolver.preResolveSnapshots`
/// before frame 0. The result is a `Set`, so the same diagram or page across
/// scenes rasterizes once (the cache deduplicates by value equality).
Set<SnapshotSource> collectSnapshotSources(List<Scene> scenes) {
  final sources = <SnapshotSource>{};
  walkSceneTree(scenes, (widget) {
    if (widget is! MediaCarrier) return;
    final source = (widget as MediaCarrier).snapshotSource;
    if (source != null) sources.add(source);
  });
  return sources;
}

/// Gathers every [Snapshot] widget from [scenes] in deterministic build order —
/// the in-process subtree-capture sibling of [collectSnapshotSources], walking
/// the same tree with no mounting and no async.
///
/// Unlike the source collectors this returns an ordered `List`, never a deduped
/// `Set`: each unkeyed `Snapshot` resolves its pre-captured raster by a stable
/// build-order index, so two distinct unkeyed instances are two captures, and
/// the order here is the order the `Snapshot`s build (the same order the capture
/// scope's order cursor hands out). The render shell hands this list to
/// `captureSnapshotChildren` (each `Snapshot.child` under the
/// `ImageResolverScope`) before frame 0, then mounts the resulting
/// `SnapshotCaptureScope` above the composition for the frame loop.
List<Snapshot> collectSnapshots(List<Scene> scenes) {
  final snapshots = <Snapshot>[];
  walkSceneTree(scenes, (widget) {
    if (widget is Snapshot) snapshots.add(widget);
  });
  return snapshots;
}

/// A clip-painting carrier paired with what the pre-pass plans against: the
/// duration of its scene in frames (`windowLength`, the longest the clip can
/// play) and its `trim` (`null` for a `Background.video`, which plays the whole
/// source).
typedef ClipPlan = ({
  MediaSource source,
  int windowStart,
  int windowLength,
  TimeRange? trim,
});

/// Pairs every clip-painting carrier in [scenes] (a `Clip` element or a
/// `Background.video`) with its scene duration in frames at [fps] and its trim —
/// the input the clip pre-pass plans source frames from.
///
/// It reuses the shared tree walk per scene, so it finds clips wherever
/// [collectMediaSources] finds their sources, then keeps only the clip-kind
/// sources (`.mp4`/`.mov`/`.webm`). The window is the whole scene because that
/// is the longest a clip can play inside it; the planner dedupes from there.
List<ClipPlan> collectClipPlans(List<Scene> scenes, int fps, {GenerativeResolver? generative}) {
  final plans = <ClipPlan>[];
  var windowStart = 0;
  for (var s = 0; s < scenes.length; s++) {
    final scene = scenes[s];
    final windowLength = resolveSceneDurationFrames(scene.duration, fps, 'scenes[$s]');
    final start = windowStart;
    void visit(Widget widget) {
      if (widget is GenerativeMedia && widget.source.kind == GenerativeKind.video) {
        if (generative == null) return;
        plans.add((
          source: generative.mediaFor(widget.source),
          windowStart: start,
          windowLength: windowLength,
          trim: widget.trim,
        ));
        return;
      }
      if (widget is! MediaCarrier) return;
      final source = (widget as MediaCarrier).mediaSource;
      if (source == null || !isClipSource(source)) return;
      plans.add((
        source: source,
        windowStart: start,
        windowLength: windowLength,
        trim: widget is Clip ? widget.trim : null,
      ));
    }

    final background = scene.background;
    if (background != null) walkWidgetTree(background, visit);
    for (final child in scene.children) {
      walkWidgetTree(child, visit);
    }
    windowStart += windowLength;
  }
  return plans;
}

/// One clip's embedded-audio plan: the `source` to extract audio from, where it
/// starts in the composition (`startFrame`), how long it plays (`windowFrames`
/// — the scene window), plus the clip's `audio` policy and any `trim`.
typedef ClipAudioPlan = ({
  MediaSource source,
  int startFrame,
  int windowFrames,
  ClipAudio audio,
  TimeRange? trim,
});

/// Gathers an audio plan for every `Clip` whose [ClipAudio] keeps its track,
/// tracking each scene's cumulative start frame so the mix can delay a clip's
/// audio to where the clip plays. Walks the same per-scene tree as
/// [collectClipPlans]; a muted clip or a non-clip source contributes nothing.
List<ClipAudioPlan> collectClipAudioPlans(
  List<Scene> scenes,
  int fps, {
  GenerativeResolver? generative,
}) {
  final plans = <ClipAudioPlan>[];
  var startFrame = 0;
  for (var s = 0; s < scenes.length; s++) {
    final scene = scenes[s];
    final windowLength = resolveSceneDurationFrames(scene.duration, fps, 'scenes[$s]');
    void visit(Widget widget) {
      // A generated video (for example Veo 3) keeps its embedded audio track,
      // delayed to its scene window exactly like a `Clip`, so the two stay in
      // sync because they are the same produced file.
      if (widget is GenerativeMedia && widget.source.kind == GenerativeKind.video) {
        if (generative == null || widget.audio.muted) return;
        if (!generative.metaFor(widget.source).hasAudio) return;
        plans.add((
          source: generative.mediaFor(widget.source),
          startFrame: startFrame,
          windowFrames: windowLength,
          audio: widget.audio,
          trim: widget.trim,
        ));
        return;
      }
      if (widget is! Clip || widget.audio.muted) return;
      final source = widget.mediaSource;
      if (source == null || !isClipSource(source)) return;
      plans.add((
        source: source,
        startFrame: startFrame,
        windowFrames: windowLength,
        audio: widget.audio,
        trim: widget.trim,
      ));
    }

    final background = scene.background;
    if (background != null) walkWidgetTree(background, visit);
    for (final child in scene.children) {
      walkWidgetTree(child, visit);
    }
    startFrame += windowLength;
  }
  return plans;
}
