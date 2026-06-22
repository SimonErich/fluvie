import 'dart:io';

import 'package:flutter/widgets.dart'
    show GlobalKey, ProxyWidget, SingleChildRenderObjectWidget, Widget;
import 'package:fluvie/src/audio/encoding/audio_mix_staging.dart';
import 'package:fluvie/src/composition/runtime/aspect_scope.dart';
import 'package:fluvie/src/composition/runtime/audio_collector.dart';
import 'package:fluvie/src/composition/runtime/media_collector.dart' show collectMediaSources;
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/aspect.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart' show MediaResolver;
import 'package:fluvie/src/core/media/media_source.dart' show MediaSource;
import 'package:fluvie/src/rendering/capture/capture_shell.dart';
import 'package:fluvie/src/rendering/capture/render_manifest.dart';
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
/// Rendering the same [composition] for the same [aspect] twice produces
/// byte-identical frames (the determinism contract the per-aspect renders-twice
/// tests prove); the encode arg array, including the mix, is byte-identical too.
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
}) async {
  final size = aspect.sizeFor(longEdge);
  final config = RenderConfig(
    width: size.width,
    height: size.height,
    fps: fps,
    frameCount: frameCount,
    cacheEnabled: cacheEnabled,
  );
  // The encoder audio mix: an explicit stager wins; otherwise a `Video`
  // composition's own `Audio` tracks are collected and staged so a public
  // `render(video, aspect:)` of an audio composition is not silent.
  final audio = _audioFor(
    composition,
    explicitStager: stageAudio,
    explicitSources: audioSources,
    fps: fps,
    totalFrames: frameCount,
  );
  // Pre-resolve declared media before the first pump: the capture shell paints
  // images synchronously from the `ImageResolverScope`, so the decoded cache
  // must be warm before the tree mounts (a null resolver = a media-less render).
  if (resolver != null) {
    await resolver.preResolveAll(_collectImageSources(composition));
  }
  final controller = RenderController();
  final boundaryKey = GlobalKey();
  final shell = buildCaptureShell(
    composition: AspectScope(aspect: aspect, child: composition),
    boundaryKey: boundaryKey,
    controller: controller,
    resolver: resolver,
  );
  await pumpWidget(shell.tree);
  final manifest = await service.captureToDirectory(
    config: config,
    outDir: outDir,
    pump: (frame) async {
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
}) {
  if (explicitStager != null) {
    return (stageAudio: explicitStager, audioSources: explicitSources ?? const []);
  }
  if (composition is! Video) return (stageAudio: null, audioSources: const []);
  final tracks = collectAudioTracks(composition);
  if (tracks.isEmpty) return (stageAudio: null, audioSources: const []);
  return (
    stageAudio: ({required resolver, required sandbox}) async {
      final plan = await stageAudioMix(
        tracks: tracks,
        resolver: resolver,
        sandbox: sandbox,
        fps: fps,
        totalFrames: totalFrames,
      );
      return (nodes: plan.tracks, amix: plan.amix);
    },
    audioSources: collectAudioSources(composition),
  );
}

/// Every declared [MediaSource] in [composition]'s scenes, or an empty set when
/// it wraps no [Video] — the collect pass `preResolveAll` warms before frame 0.
/// The `Video` is unwrapped through the transparent single-child wrappers
/// `renderTemplate` adds (a `Directionality`), so both a bare `Video` and a
/// wrapped one resolve their media.
Set<MediaSource> _collectImageSources(Widget composition) {
  final video = _videoIn(composition);
  return video == null ? const {} : collectMediaSources(video.scenes);
}

/// The first [Video] at or below [widget], descending only the transparent
/// single-child wrappers (`InheritedWidget`s and single-child render objects);
/// `null` when there is none.
Video? _videoIn(Widget widget) => switch (widget) {
  Video() => widget,
  ProxyWidget(:final child) => _videoIn(child),
  SingleChildRenderObjectWidget(:final child?) => _videoIn(child),
  _ => null,
};
