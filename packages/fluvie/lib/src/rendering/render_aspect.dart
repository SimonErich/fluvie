import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart' show Widget;
import 'package:fluvie/src/audio/encoding/audio_mix_staging.dart';
import 'package:fluvie/src/composition/runtime/audio_collector.dart';
import 'package:fluvie/src/composition/runtime/clip_plan_collector.dart'
    show ClipAudioPlan, collectClipAudioPlans;
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/aspect.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/contracts/beat_detection_service.dart';
import 'package:fluvie/src/core/contracts/frequency_analyzer.dart';
import 'package:fluvie/src/core/contracts/generative_resolver.dart'
    show GenerativeProgress, GenerativeResolver;
import 'package:fluvie/src/core/contracts/media_resolver.dart' show MediaResolver;
import 'package:fluvie/src/core/contracts/snapshot_service.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/export.dart';
import 'package:fluvie/src/core/quality.dart';
import 'package:fluvie/src/media/render_resolver_scope.dart';
import 'package:fluvie/src/rendering/capture/render_manifest.dart';
import 'package:fluvie/src/rendering/clip_audio_staging.dart';
import 'package:fluvie/src/rendering/collect_composition_media.dart';
import 'package:fluvie/src/rendering/composition_capture_host.dart';
import 'package:fluvie/src/rendering/composition_session.dart';
import 'package:fluvie/src/rendering/no_generative_resolver.dart';
import 'package:fluvie/src/rendering/no_media_resolver.dart' show NoMediaResolver;
import 'package:fluvie/src/rendering/prepared_composition.dart';
import 'package:fluvie/src/rendering/render_cancellation.dart';
import 'package:fluvie/src/rendering/render_config.dart';
import 'package:fluvie/src/rendering/render_host_callbacks.dart';
import 'package:fluvie/src/rendering/render_service.dart';
import 'package:fluvie/src/rendering/video_render_request.dart';

export 'render_host_callbacks.dart';

part 'render_aspect_audio.dart';

/// The captured manifest and its resolved canvas, clock and output range.
typedef RenderAspectResult = ({RenderManifest manifest, RenderConfig config});

/// Prepares and captures an ordinary Flutter composition using one mounted session.
///
/// [request] preserves exact canvas pixels and an authored capture range. Without
/// it, [aspect] and [longEdge] select the canvas. Mounted Video export/poster
/// settings and embedded clip audio are resolved before capture. In-process
/// Snapshot children are frozen in their original layout and timing scopes.
///
/// The host supplies Flutter pumps and optionally [runAsync] for test bindings.
/// An injected resolver stays caller-owned; the default scoped resolver is
/// released here. [stageAudio] overrides automatic authored-track mixing.
Future<RenderAspectResult> render({
  required Widget composition,
  required Aspect aspect,
  required int frameCount,
  required Directory outDir,
  required RenderService service,
  required ShellMount pumpWidget,
  required ShellFramePump pumpFrame,
  ShellRunAsync runAsync = runAsyncDirectly,
  int longEdge = VideoDefaults.longEdge,
  int fps = VideoDefaults.fps,
  Quality? quality,
  Export? export,
  String compositionKey = 'render',
  bool cacheEnabled = false,
  VideoRenderRequest? request,
  RenderCancellation? cancellation,
  BeatDetectionService? beatDetector,
  FrequencyAnalyzer? analyzer,
  SnapshotService? snapshotService,
  ProgressCallback? onProgress,
  FutureOr<void> Function(PreparedComposition prepared, VideoRenderRequest request)? onPrepared,
  AudioMixStager? stageAudio,
  Iterable<AudioSource>? audioSources,
  MediaResolver? resolver,
  GenerativeResolver generative = const NoGenerativeResolver(),
  void Function(GenerativeProgress progress)? onGenerativeProgress,
}) async {
  final size = aspect.sizeFor(longEdge);
  final effective =
      request ??
      VideoRenderRequest(
        composition: composition,
        width: size.width,
        height: size.height,
        fps: fps,
        frameCount: frameCount,
        aspect: aspect,
        quality: quality,
        export: export,
      );
  final authored = effective.composition;
  cancellation ??= effective.cancellation;
  final scope = resolverScope(
    resolver ?? (service.media is NoMediaResolver ? null : service.media),
    whenCancelled: cancellation?.whenCancelled,
  );
  final active = scope.resolver;
  final session = CompositionSession(
    composition: authored,
    clipLookaheadFrames: 15,
    resolver: active,
    generative: generative,
    onGenerativeProgress: onGenerativeProgress,
    hostFps: effective.fps,
    hostFrameCount: effective.startFrame + effective.frameCount,
    cancellation: cancellation,
    beatDetector: beatDetector,
    analyzer: analyzer,
    snapshotService: snapshotService,
  );
  final host = CompositionCaptureHost(session: session, request: effective);
  try {
    await host.prepare(
      mount: pumpWidget,
      pump: pumpFrame,
      runAsync: runAsync,
      onPrepared: onPrepared,
    );
    final resolved = host.request;
    final config = resolved.config.copyWith(cacheEnabled: cacheEnabled);
    final audio = _audioFor(
      session.video ?? authored,
      explicitStager: stageAudio,
      explicitSources: audioSources,
      fps: resolved.fps,
      totalFrames: session.prepared.totalFrames,
      generative: generative,
      resolver: active,
      mountedClipPlans: session.clipAudioPlans,
    );
    late final RenderManifest manifest;
    await runAsync(() async {
      manifest = await service.captureToDirectory(
        config: config,
        outDir: outDir,
        pump: (frame) => host.pumpFrame(frame, pumpFrame),
        boundaryKey: host.boundaryKey,
        compositionKey: '$compositionKey-${aspect.name}',
        audioSources: audio.audioSources,
        stageAudio: audio.stageAudio,
        mediaResolver: active,
        export: resolved.export,
        posterFrame: resolved.posterFrame,
        cancellation: cancellation,
        onProgress: onProgress,
      );
      return null;
    });
    return (manifest: manifest, config: config);
  } finally {
    host.dispose();
    await scope.dispose();
  }
}
