import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:fluvie/src/audio/encoding/resolved_audio_track.dart';
import 'package:fluvie/src/composition/runtime/aspect_scope.dart';
import 'package:fluvie/src/core/aspect.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart' show MediaResolver;
import 'package:fluvie/src/core/export.dart';
import 'package:fluvie/src/rendering/audio_sandbox_staging.dart';
import 'package:fluvie/src/rendering/capture/capture_shell.dart';
import 'package:fluvie/src/rendering/capture/frame_capture_service.dart';
import 'package:fluvie/src/rendering/capture/render_manifest.dart';
import 'package:fluvie/src/rendering/collect_composition_media.dart';
import 'package:fluvie/src/rendering/encoding/content_hash.dart';
import 'package:fluvie/src/rendering/encoding/video_encoder_service.dart';
import 'package:fluvie/src/rendering/frame_capture_loop.dart';
import 'package:fluvie/src/rendering/io/render_sandbox.dart';
import 'package:fluvie/src/rendering/pre_resolve_clips.dart';
import 'package:fluvie/src/rendering/render_config.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';

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

/// Renders [composition] for [aspect] into [sandbox] without touching the file
/// system — the in-memory, `dart:io`-free capture-and-plan path the web encoder
/// drives.
///
/// It mirrors the file-based `render`: it re-derives the canvas from
/// `aspect.sizeFor(longEdge)`, builds the production [buildCaptureShell], pumps
/// it through [pumpWidget] / [pumpFrame], runs the shared [runFrameCaptureLoop]
/// into [sandbox]'s frames file, then writes `manifest.json` there. The caller
/// (the web encoder) reads [sandbox] to feed ffmpeg.wasm and returns the encoded
/// bytes. Rendering the same composition produces the same frames, the same as
/// the file path.
///
/// Pass [audioTracks] (resolved by `resolveAudioMix`) plus a [loadAudioBytes]
/// loader to mix audio: each track is staged into [sandbox] by
/// [stageResolvedAudioToSandbox] and its `amix` plan flows into the encode args,
/// scaled by [audioMasterVolume]. With no tracks (or no loader) the plan carries
/// `-an`, matching a video-only render. Audio rides the MP4 export only;
/// the other export modes ignore it.
///
/// Pass a [resolver] to paint declared image media: it pre-resolves every
/// collected `MediaSource` before the first pump and is mounted as the
/// `ImageResolverScope`, so paint reads the decoded cache synchronously. A null
/// [resolver] renders a media-less composition (any declared image throws).
Future<RenderManifest> renderToSandbox({
  required Widget composition,
  required Aspect aspect,
  required int frameCount,
  required RenderSandbox sandbox,
  required FrameCaptureService capture,
  required SandboxMount pumpWidget,
  required SandboxFramePump pumpFrame,
  int longEdge = 1920,
  int fps = 30,
  String compositionKey = 'render',
  Export? export,
  int? posterFrame,
  ProgressCallback? onProgress,
  VideoEncoderService encoder = const VideoEncoderService(),
  List<ResolvedAudioTrack> audioTracks = const [],
  AudioByteLoader? loadAudioBytes,
  double audioMasterVolume = 1,
  MediaResolver? resolver,
  FrameEncoder? frameEncoder,
}) async {
  if (audioTracks.isNotEmpty && loadAudioBytes == null) {
    throw ArgumentError.value(
      audioTracks,
      'audioTracks',
      'loadAudioBytes is required to stage audio; pass one or leave audioTracks empty',
    );
  }
  final size = aspect.sizeFor(longEdge);
  final config = RenderConfig(
    width: size.width,
    height: size.height,
    fps: fps,
    frameCount: frameCount,
  );
  // Pre-resolve declared media before the first pump: the capture shell paints
  // images synchronously from the `ImageResolverScope`, so the decoded cache
  // must be warm before the tree mounts (a null resolver = a media-less render).
  if (resolver != null) {
    await resolver.preResolveAll(collectCompositionMedia(composition));
    await preResolveCompositionClips(
      composition: composition,
      resolver: resolver,
      totalFrames: frameCount,
    );
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

  final digest = renderDigest(
    config: config,
    compositionKey: '$compositionKey-${aspect.name}',
    fluvieVersion: fluvieRenderVersion,
  );
  await sandbox.create();
  // The browser path (frameEncoder set) writes one bounded-size PNG per frame as
  // it is captured; every other backend appends raw RGBA to one frames stream.
  final framesArePng = frameEncoder != null;
  Future<void> pump(int frame) async {
    controller.seek(frame);
    await pumpFrame();
  }

  if (framesArePng) {
    await runFrameCaptureLoop(
      config: config,
      digest: digest,
      pump: pump,
      boundaryKey: boundaryKey,
      capture: capture,
      onFrame: (raw) async {
        final png = await frameEncoder(raw.rgba, raw.width, raw.height);
        await sandbox.writeBytes(VideoEncoderService.framesPngName(raw.frameIndex), png);
      },
      onProgress: onProgress,
    );
  } else {
    final sink = sandbox.openFrames(VideoEncoderService.framesFileName);
    try {
      await runFrameCaptureLoop(
        config: config,
        digest: digest,
        pump: pump,
        boundaryKey: boundaryKey,
        sink: sink,
        capture: capture,
        onProgress: onProgress,
      );
    } finally {
      await sink.close();
    }
  }

  final audioPlan = (audioTracks.isEmpty || loadAudioBytes == null)
      ? null
      : await stageResolvedAudioToSandbox(
          tracks: audioTracks,
          sandbox: sandbox,
          loadBytes: loadAudioBytes,
          masterVolume: audioMasterVolume,
        );

  final manifest = RenderManifest(
    width: config.width,
    height: config.height,
    fps: config.fps,
    frameCount: config.frameCount,
    framesFileName: framesArePng
        ? VideoEncoderService.framesPngPattern
        : VideoEncoderService.framesFileName,
    outputFileName: encoder.outputNameFor(export),
    renderDigest: digest,
    ffmpegArgs: encoder.planEncodeArgs(
      config,
      audio: audioPlan?.tracks ?? const [],
      amix: audioPlan?.amix,
      export: export,
      framesArePng: framesArePng,
    ),
    posterFileName: posterFrame == null ? null : VideoEncoderService.posterFileName,
    posterArgs: posterFrame == null
        ? null
        : encoder.planPosterArgs(config, posterFrame: posterFrame, framesArePng: framesArePng),
  );
  await sandbox.writeText('manifest.json', jsonEncode(manifest.toJson()));
  return manifest;
}
