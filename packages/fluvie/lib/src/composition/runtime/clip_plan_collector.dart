import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/motion_target.dart';
import 'package:fluvie/src/composition/clip_transition.dart';
import 'package:fluvie/src/composition/runtime/clip_transition_audio.dart';
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
import 'package:fluvie/src/elements/runtime/clip_speed_profile.dart';
import 'package:fluvie/src/timing/placement/scene_frame_resolver.dart';
import 'package:fluvie/src/timing/placement/window_resolver.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

part 'clip_plan_scene_walk.dart';

/// A clip-painting carrier paired with what the pre-pass plans against: the
/// window the element is alive over in composition frames (`windowStart` for
/// `windowLength` frames) and its `trim` (`null` for a `Background.video`,
/// which plays the whole source).
///
/// The window is the **element's**, not its scene's: it is exactly the scope
/// `WindowScope` publishes and `ClipPainter` resamples against, so the frames
/// planned here are the frames paint asks for.
typedef ClipPlan = ({
  MediaSource source,
  int windowStart,
  int windowLength,
  TimeRange? trim,
  double speed,
  List<double>? sourceTimeMap,
});

/// Pairs every clip-painting carrier in [scenes] (a `Clip` element or a
/// `Background.video`) with the composition window it is alive over and its
/// trim — the input the clip pre-pass plans source frames from.
///
/// [sceneStartFrames] is the resolved absolute start of each scene, in scene
/// order — `Video.sceneStartFrames`, which is the same offset math the
/// compositor mounts against. It cannot be re-derived here by summing
/// durations: an overlapping transition starts the next scene early, so a
/// running sum drifts later by every blend window before it.
///
/// It reuses the shared scope-threading walk per scene, so it finds clips
/// wherever `collectMediaSources` finds their sources and sees each one under
/// the scope it will render in, then keeps only the clip-kind sources
/// (`.mp4`/`.mov`/`.webm`).
List<ClipPlan> collectClipPlans(
  List<Scene> scenes,
  int fps, {
  required List<int> sceneStartFrames,
  GenerativeResolver? generative,
  List<Widget> overlays = const [],
  int totalFrames = 0,
}) {
  final plans = <ClipPlan>[];
  _walkScenes(scenes, fps, sceneStartFrames, overlays, totalFrames, (widget, scope, audioFor) {
    if (widget is GenerativeMedia && widget.source.kind == GenerativeKind.video) {
      if (generative == null) return;
      plans.add((
        source: generative.mediaFor(widget.source),
        windowStart: scope.startFrame,
        windowLength: scope.durationFrames,
        trim: widget.trim,
        // A generated video has no rate of its own; it plays as produced.
        speed: 1,
        sourceTimeMap: null,
      ));
      return;
    }
    if (widget is! MediaCarrier) return;
    final source = (widget as MediaCarrier).mediaSource;
    if (source == null || (widget is! Clip && !isClipSource(source))) return;
    plans.add((
      source: source,
      windowStart: scope.startFrame,
      windowLength: scope.durationFrames,
      trim: widget is Clip ? widget.trim : null,
      // A Background.video plays at source speed; only a Clip carries a rate.
      speed: widget is Clip ? widget.speed : 1,
      sourceTimeMap: widget is Clip && widget.speedRamp != null
          ? integrateClipSpeedRamp(widget.speedRamp!, fps: fps, windowFrames: scope.durationFrames)
          : null,
    ));
  });
  return plans;
}

/// One clip's embedded-audio plan: the `source` to extract audio from, where it
/// starts in the composition (`startFrame`), how long it plays
/// (`windowFrames`), plus the clip's `audio` policy and any `trim`.
///
/// Like [ClipPlan] these describe the **element's** window, so a clip shown
/// part-way into its scene is heard when it appears rather than from the top of
/// the scene.
typedef ClipAudioPlan = ({
  MediaSource source,
  int startFrame,
  int windowFrames,
  ClipAudio audio,
  TimeRange? trim,
  double speed,
  List<double>? sourceTimeMap,
});

/// Gathers an audio plan for every `Clip` whose [ClipAudio] keeps its track,
/// against the resolved [sceneStartFrames] so the mix delays a clip's audio to
/// where the clip actually plays. Walks the same scoped per-scene tree as
/// [collectClipPlans]; a muted clip or a non-clip source contributes nothing.
List<ClipAudioPlan> collectClipAudioPlans(
  List<Scene> scenes,
  int fps, {
  required List<int> sceneStartFrames,
  GenerativeResolver? generative,
  List<Widget> overlays = const [],
  int totalFrames = 0,
}) {
  final plans = <ClipAudioPlan>[];
  _walkScenes(scenes, fps, sceneStartFrames, overlays, totalFrames, (widget, scope, audioFor) {
    // A generated video (for example Veo 3) keeps its embedded audio track,
    // delayed to its window exactly like a `Clip`, so the two stay in sync
    // because they are the same produced file.
    if (widget is GenerativeMedia && widget.source.kind == GenerativeKind.video) {
      if (generative == null || widget.audio.muted) return;
      if (!generative.metaFor(widget.source).hasAudio) return;
      plans.add((
        source: generative.mediaFor(widget.source),
        startFrame: scope.startFrame,
        windowFrames: scope.durationFrames,
        audio: audioFor(widget.audio),
        trim: widget.trim,
        speed: 1,
        sourceTimeMap: null,
      ));
      return;
    }
    if (widget is! Clip || widget.audio.muted) return;
    final source = widget.mediaSource;
    if (source == null) return;
    plans.add((
      source: source,
      startFrame: scope.startFrame,
      windowFrames: scope.durationFrames,
      audio: audioFor(widget.audio),
      trim: widget.trim,
      speed: widget.speed,
      sourceTimeMap: widget.speedRamp == null
          ? null
          : integrateClipSpeedRamp(widget.speedRamp!, fps: fps, windowFrames: scope.durationFrames),
    ));
  });
  return plans;
}
