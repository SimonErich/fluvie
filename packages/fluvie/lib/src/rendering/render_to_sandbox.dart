import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:fluvie/src/audio/encoding/audio_mix_plan.dart';
import 'package:fluvie/src/audio/encoding/resolved_audio_track.dart';
import 'package:fluvie/src/core/aspect.dart';
import 'package:fluvie/src/core/contracts/generative_resolver.dart'
    show GenerativeProgress, GenerativeResolver;
import 'package:fluvie/src/core/contracts/media_resolver.dart' show MediaResolver;
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/export.dart';
import 'package:fluvie/src/media/render_resolver_scope.dart';
import 'package:fluvie/src/rendering/audio_sandbox_staging.dart';
import 'package:fluvie/src/rendering/capture/frame_capture_service.dart';
import 'package:fluvie/src/rendering/capture/render_manifest.dart';
import 'package:fluvie/src/rendering/composition_capture_host.dart';
import 'package:fluvie/src/rendering/composition_session.dart';
import 'package:fluvie/src/rendering/encoding/content_hash.dart';
import 'package:fluvie/src/rendering/encoding/video_encoder_service.dart';
import 'package:fluvie/src/rendering/frame_capture_loop.dart';
import 'package:fluvie/src/rendering/io/render_sandbox.dart';
import 'package:fluvie/src/rendering/no_generative_resolver.dart';
import 'package:fluvie/src/rendering/prepared_composition.dart';
import 'package:fluvie/src/rendering/render_cancellation.dart';
import 'package:fluvie/src/rendering/render_config.dart';
import 'package:fluvie/src/rendering/render_output_intent.dart';
import 'package:fluvie/src/rendering/video_render_request.dart';

part 'render_to_sandbox_frames.dart';
part 'render_to_sandbox_manifest.dart';

/// Mounts a capture shell ([Widget]) into the host before the frame loop.
typedef SandboxMount = Future<void> Function(Widget tree);

/// Pumps the host one frame after the controller seeks.
typedef SandboxFramePump = Future<void> Function();

/// Compresses one captured frame's raw RGBA pixels to encoder-ready bytes.
///
/// The browser passes a PNG encoder here so each frame is written to its own
/// small `frame_NNNNNN.png` file as it is captured, instead of accumulating
/// every raw frame into one multi-gigabyte buffer that overflows browser/wasm
/// memory. With no encoder the render writes the single raw RGBA stream.
typedef FrameEncoder = Future<Uint8List> Function(Uint8List rgba, int width, int height);

/// Resolves an encoder's mix after actual mounted media discovery and probing.
typedef AudioMixResolver = FutureOr<ResolvedAudioMix?> Function(CompositionSession session);

/// Captures the mounted Flutter composition into a bounded [sandbox].
///
/// [request] supplies exact canvas geometry, capture range and output policy.
/// Without a request, [aspect], [longEdge], [fps] and [frameCount] apply.
/// Mounted authored timing remains complete when capturing a prefix. Ordinary
/// Flutter snapshots are prepared automatically; [onPrepared] receives the
/// shared immutable plan before the first output frame.
///
/// [frameEncoder] stores one PNG per frame instead of one RGBA stream.
/// Audio is resolved after mounted discovery through [resolveAudio], or from
/// [audioTracks]. Tracks require [loadAudioBytes] for sandbox materialization.
/// The caller owns encoding and any supplied [resolver].
Future<RenderManifest> renderToSandbox({
  required Widget composition,
  required Aspect aspect,
  required int frameCount,
  required RenderSandbox sandbox,
  required FrameCaptureService capture,
  required SandboxMount pumpWidget,
  required SandboxFramePump pumpFrame,
  int longEdge = VideoDefaults.longEdge,
  int fps = VideoDefaults.fps,
  String compositionKey = 'render',
  Export? export,
  int? posterFrame,
  ProgressCallback? onProgress,
  VideoEncoderService encoder = const VideoEncoderService(),
  List<ResolvedAudioTrack> audioTracks = const [],
  AudioByteLoader? loadAudioBytes,
  double audioMasterVolume = 1,
  MediaResolver? resolver,
  GenerativeResolver generative = const NoGenerativeResolver(),
  void Function(GenerativeProgress progress)? onGenerativeProgress,
  FrameEncoder? frameEncoder,
  AudioMixResolver? resolveAudio,
  VideoRenderRequest? request,
  RenderCancellation? cancellation,
  FutureOr<void> Function(PreparedComposition prepared, VideoRenderRequest request)? onPrepared,
}) async {
  if (audioTracks.isNotEmpty && loadAudioBytes == null) {
    throw ArgumentError.value(
      audioTracks,
      'audioTracks',
      'loadAudioBytes is required to stage audio; pass one or leave audioTracks empty',
    );
  }
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
        export: export,
        posterFrame: posterFrame,
      );
  final authored = effective.composition;
  cancellation ??= effective.cancellation;
  final scope = resolverScope(resolver, whenCancelled: cancellation?.whenCancelled);
  final session = CompositionSession(
    composition: authored,
    resolver: scope.resolver,
    generative: generative,
    onGenerativeProgress: onGenerativeProgress,
    hostFps: effective.fps,
    hostFrameCount: effective.startFrame + effective.frameCount,
    cancellation: cancellation,
    clipLookaheadFrames: 15,
  );
  final host = CompositionCaptureHost(session: session, request: effective);
  try {
    await host.prepare(
      mount: pumpWidget,
      pump: pumpFrame,
      onPrepared: onPrepared,
    );
    final resolved = host.request;
    final config = resolved.config;
    final resolvedExport = resolved.export;
    final resolvedPoster = resolved.posterFrame;
    final resolvedMix = resolveAudio == null
        ? null
        : await (cancellation?.run(() async => resolveAudio(session)) ??
              Future.sync(() => resolveAudio(session)));
    final resolvedTracks = resolvedMix?.tracks ?? audioTracks;
    if (resolvedTracks.isNotEmpty && loadAudioBytes == null) {
      throw ArgumentError('loadAudioBytes is required to stage the resolved composition audio.');
    }

    final digest = renderDigest(
      config: config,
      compositionKey: '$compositionKey-${aspect.name}',
      fluvieVersion: fluvieRenderVersion,
    );
    await sandbox.create();
    // The browser path (frameEncoder set) writes one bounded-size PNG per frame as
    // it is captured; every other backend appends raw RGBA to one frames stream.
    final framesArePng = frameEncoder != null;
    await _captureSandboxFrames(
      config: config,
      digest: digest,
      pump: (frame) => host.pumpFrame(frame, pumpFrame),
      boundaryKey: host.boundaryKey,
      capture: capture,
      sandbox: sandbox,
      frameEncoder: frameEncoder,
      onProgress: onProgress,
      cancellation: cancellation,
    );

    final audioPlan = (resolvedTracks.isEmpty || loadAudioBytes == null)
        ? null
        : await stageResolvedAudioToSandbox(
            tracks: resolvedTracks,
            sandbox: sandbox,
            loadBytes: loadAudioBytes,
            masterVolume: resolvedMix?.masterVolume ?? audioMasterVolume,
          );

    final manifest = _sandboxManifest(
      config: config,
      encoder: encoder,
      framesArePng: framesArePng,
      digest: digest,
      resolvedExport: resolvedExport,
      audioPlan: audioPlan,
      resolvedPoster: resolvedPoster,
    );
    cancellation?.throwIfCancelled();
    await sandbox.writeText('manifest.json', jsonEncode(manifest.toJson()));
    cancellation?.throwIfCancelled();
    return manifest;
  } finally {
    host.dispose();
    await scope.dispose();
  }
}
