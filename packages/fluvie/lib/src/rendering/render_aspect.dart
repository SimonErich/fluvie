import 'dart:io';

import 'package:flutter/widgets.dart' show GlobalKey, Widget;
import 'package:fluvie/src/audio/encoding/audio_mix_staging.dart';
import 'package:fluvie/src/composition/runtime/aspect_scope.dart';
import 'package:fluvie/src/composition/runtime/audio_collector.dart';
import 'package:fluvie/src/composition/runtime/media_collector.dart'
    show ClipAudioPlan, collectClipAudioPlans;
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/aspect.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/contracts/clip_frame_preparer.dart';
import 'package:fluvie/src/core/contracts/generative_resolver.dart'
    show GenerativeProgress, GenerativeResolver;
import 'package:fluvie/src/core/contracts/media_resolver.dart' show MediaResolver;
import 'package:fluvie/src/rendering/capture/capture_shell.dart';
import 'package:fluvie/src/rendering/capture/render_manifest.dart';
import 'package:fluvie/src/rendering/clip_audio_staging.dart';
import 'package:fluvie/src/rendering/collect_composition_media.dart';
import 'package:fluvie/src/rendering/no_generative_resolver.dart';
import 'package:fluvie/src/rendering/pre_resolve_clips.dart';
import 'package:fluvie/src/rendering/render_config.dart';
import 'package:fluvie/src/rendering/render_service.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';

/// Mounts [tree] (the full capture shell) into the host's element tree before
/// the frame loop starts. A widget test passes `tester.pumpWidget`; the CLI
/// passes its binding's pump.
typedef ShellMount = Future<void> Function(Widget tree);

/// Pumps the host one frame after the controller seeks, so the just-seeked
/// frame is fully built before its pixels are read. A widget test passes
/// `() => tester.pump()`; the CLI passes its binding's pump.
typedef ShellFramePump = Future<void> Function();

/// What [render] returns: the captured `manifest` and the `config` whose width
/// and height were re-derived from `Aspect.sizeFor` for the rendered aspect.
typedef RenderAspectResult = ({RenderManifest manifest, RenderConfig config});

/// Renders [composition] for a single [aspect] — the canonical multi-aspect
/// entry.
///
/// It re-derives the canvas size from `aspect.sizeFor(longEdge)` (ignoring any
/// size the composition declares for itself), mounts an [AspectScope] over the
/// composition so every `Adaptive` and `AspectScope.of(context)` branch lays out
/// for this aspect, builds the production [buildCaptureShell] around it, and runs the
/// shell once through [RenderService.captureToDirectory]. Timing and animations
/// resolve identically across aspects — the same plan resolves; only layout
/// branches — so the per-aspect renders share a clock and differ only in shape.
///
/// This is distinct from [RenderService.render], the instance method that
/// captures and encodes one fixed-size composition: [render] is the free
/// function that re-derives the size per aspect and drives that same service.
/// (It is also distinct from `renderTemplate`, which renders a parameterized
/// `VideoTemplate` — Dart has no overloading, so each is its own free function.)
///
/// The host owns the pumping mechanics through [pumpWidget] and [pumpFrame],
/// which keeps this offline and gate-runnable (the example and goldens pass a
/// `flutter_test` pump; the CLI passes its binding's). To encode the result, run
/// the returned manifest's ffmpeg args through an `FfmpegProvider`.
///
/// When [composition] is a [Video] that declares `Audio`, its tracks are staged
/// into the encoder mix by default: the resulting
/// file is **not silent**. Pass [stageAudio] (with [audioSources]) to override
/// the default — for example when the audio-bearing `Video` is wrapped in
/// another widget the auto-collect cannot reach. A `Video` with no audio (or a
/// non-`Video` composition) stages nothing, so the encoder's `-an` path stands.
///
/// Pass a [resolver] to render declared media: its sources are collected from
/// [composition] and pre-resolved before the first pump, and it is mounted as
/// the `ImageResolverScope` the elements paint from. A null [resolver] keeps the
/// media-less path (a composition that declares an `Image`/`Clip` then throws a
/// `FluvieRenderException` naming the missing pre-resolution).
///
/// Each [aspect] re-derives its size from [longEdge] and renders independently,
/// so the same [composition] renders the same frames for that aspect; the encode
/// arg array, including the mix, is built from the plan.
Future<RenderAspectResult> render({
  required Widget composition,
  required Aspect aspect,
  required int frameCount,
  required Directory outDir,
  required RenderService service,
  required ShellMount pumpWidget,
  required ShellFramePump pumpFrame,
  int longEdge = 1920,
  int fps = 30,
  String compositionKey = 'render',
  bool cacheEnabled = false,
  AudioMixStager? stageAudio,
  Iterable<AudioSource>? audioSources,
  MediaResolver? resolver,
  GenerativeResolver generative = const NoGenerativeResolver(),
  void Function(GenerativeProgress progress)? onGenerativeProgress,
}) async {
  final size = aspect.sizeFor(longEdge);
  final config = RenderConfig(
    width: size.width,
    height: size.height,
    fps: fps,
    frameCount: frameCount,
    cacheEnabled: cacheEnabled,
  );
  // Pre-resolve declared and generated media before reading audio: generation
  // produces the files, the media pre-pass warms the decode cache, and the clip
  // pre-pass probes each clip — so the audio collector below knows which clips
  // actually carry an audio track. A null resolver is a media-less render.
  if (resolver != null) {
    await generative.generateAll(
      collectCompositionGenerative(composition),
      onProgress: onGenerativeProgress,
    );
    await resolver.preResolveAll(collectCompositionMedia(composition, generative: generative));
    await preResolveCompositionClips(
      composition: composition,
      resolver: resolver,
      totalFrames: frameCount,
      generative: generative,
    );
  }
  // The encoder audio mix: an explicit stager wins; otherwise a `Video`
  // composition's own `Audio` tracks (plus any generated audio and a clip's
  // embedded audio) are collected and staged so a public `render(video, aspect:)`
  // of an audio composition is not silent.
  final audio = _audioFor(
    composition,
    explicitStager: stageAudio,
    explicitSources: audioSources,
    fps: fps,
    totalFrames: frameCount,
    generative: resolver != null ? generative : null,
    resolver: resolver,
  );
  final controller = RenderController();
  final boundaryKey = GlobalKey();
  final shell = buildCaptureShell(
    composition: AspectScope(aspect: aspect, child: composition),
    boundaryKey: boundaryKey,
    controller: controller,
    resolver: resolver,
    generativeResolver: generative,
  );
  final preparer = resolver != null && resolver is ClipFramePreparer
      ? resolver as ClipFramePreparer
      : null;
  // Warm the first frame's clip window before the tree mounts: the initial
  // pumpWidget builds at frame 0, before the capture loop's first decode-ahead,
  // so without this the first build's synchronous clip lookup would miss (that
  // build is not captured — the loop re-pumps frame 0 — but it would still throw).
  await preparer?.prepareClipFrames(0);
  await pumpWidget(shell.tree);
  final manifest = await service.captureToDirectory(
    config: config,
    outDir: outDir,
    pump: (frame) async {
      // Decode-ahead: a streaming resolver warms just the clip frames this
      // composition frame paints before the tree builds, so paint's
      // synchronous clip lookup is a hit without holding every frame in memory.
      await preparer?.prepareClipFrames(frame);
      controller.seek(frame);
      shell.mountedSnapshotScope?.resetCursor();
      await pumpFrame();
    },
    boundaryKey: boundaryKey,
    compositionKey: '$compositionKey-${aspect.name}',
    audioSources: audio.audioSources,
    stageAudio: audio.stageAudio,
  );
  return (manifest: manifest, config: config);
}

/// Resolves the encoder audio mix for [composition]: an explicit
/// [explicitStager]/[explicitSources] pair wins; otherwise a [Video]
/// composition's declared `Audio` tracks are collected and turned into a
/// [stageAudioMix] closure against [fps]/[totalFrames] (so `Audio.sfx(at:)`
/// resolves its `adelay`). A non-`Video` or track-less composition yields
/// `(null, const [])`, so the encoder's `-an` path is unchanged.
({AudioMixStager? stageAudio, Iterable<AudioSource> audioSources}) _audioFor(
  Widget composition, {
  required AudioMixStager? explicitStager,
  required Iterable<AudioSource>? explicitSources,
  required int fps,
  required int totalFrames,
  GenerativeResolver? generative,
  MediaResolver? resolver,
}) {
  if (explicitStager != null) {
    return (stageAudio: explicitStager, audioSources: explicitSources ?? const []);
  }
  if (composition is! Video) return (stageAudio: null, audioSources: const []);
  final tracks = collectAudioTracks(composition, generative: generative);
  // Only clips that actually carry an audio track join the mix (each was probed
  // above); a silent clip would otherwise fail the encoder's `[N:a]` map.
  final clipPlans = resolver == null
      ? const <ClipAudioPlan>[]
      : collectClipAudioPlans(
          composition.scenes,
          fps,
          generative: generative,
        ).where((plan) => resolver.clipMetadataFor(plan.source).hasAudio).toList();
  if (tracks.isEmpty && clipPlans.isEmpty) {
    return (stageAudio: null, audioSources: const []);
  }
  return (
    stageAudio: ({required resolver, required sandbox}) async {
      // A clip's embedded audio (including a generated video's) is staged from
      // the clip's video file and joins the same amix as the declared tracks.
      final clipNodes = await stageClipAudio(
        plans: clipPlans,
        resolver: resolver,
        sandbox: sandbox,
        fps: fps,
        totalFrames: totalFrames,
      );
      final plan = await stageAudioMix(
        tracks: tracks,
        resolver: resolver,
        sandbox: sandbox,
        fps: fps,
        totalFrames: totalFrames,
        extraNodes: clipNodes,
      );
      return (nodes: plan.tracks, amix: plan.amix);
    },
    audioSources: {
      ...collectAudioSources(composition, generative: generative),
      for (final plan in clipPlans) clipAudioSourceFor(plan.source),
    },
  );
}
