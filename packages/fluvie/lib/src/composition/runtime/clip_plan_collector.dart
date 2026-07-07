import 'package:flutter/widgets.dart';
import 'package:fluvie/src/composition/runtime/scene_tree_walk.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/core/contracts/generative_resolver.dart';
import 'package:fluvie/src/core/media/clip_audio.dart';
import 'package:fluvie/src/core/media/clip_source_kind.dart';
import 'package:fluvie/src/core/media/generative_kind.dart';
import 'package:fluvie/src/core/media/media_carrier.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/elements/clip.dart';
import 'package:fluvie/src/elements/generative_media.dart';
import 'package:fluvie/src/timing/placement/scene_frame_resolver.dart';

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
/// `collectMediaSources` finds their sources, then keeps only the clip-kind
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
