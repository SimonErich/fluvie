import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:fluvie/src/audio/encoding/resolved_audio_track.dart';
import 'package:fluvie/src/composition/runtime/aspect_scope.dart';
import 'package:fluvie/src/core/aspect.dart';
import 'package:fluvie/src/core/export.dart';
import 'package:fluvie/src/rendering/audio_sandbox_staging.dart';
import 'package:fluvie/src/rendering/capture/capture_shell.dart';
import 'package:fluvie/src/rendering/capture/frame_capture_service.dart';
import 'package:fluvie/src/rendering/capture/render_manifest.dart';
import 'package:fluvie/src/rendering/encoding/content_hash.dart';
import 'package:fluvie/src/rendering/encoding/video_encoder_service.dart';
import 'package:fluvie/src/rendering/frame_capture_loop.dart';
import 'package:fluvie/src/rendering/io/render_sandbox.dart';
import 'package:fluvie/src/rendering/render_config.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';

/// Mounts a capture shell ([Widget]) into the host before the frame loop.
typedef SandboxMount = Future<void> Function(Widget tree);

/// Pumps the host one frame after the controller seeks.
typedef SandboxFramePump = Future<void> Function();

/// Renders [composition] for [aspect] into [sandbox] without touching the file
/// system — the in-memory, `dart:io`-free capture-and-plan path the web encoder
/// drives.
///
/// It mirrors the file-based `render`: it re-derives the canvas from
/// `aspect.sizeFor(longEdge)`, builds the production [buildCaptureShell], pumps
/// it through [pumpWidget] / [pumpFrame], runs the shared [runFrameCaptureLoop]
/// into [sandbox]'s frames file, then writes `manifest.json` there. The caller
/// (the web encoder) reads [sandbox] to feed ffmpeg.wasm and returns the encoded
/// bytes. Rendering the same composition twice produces byte-identical frames —
/// the same determinism contract as the file path.
///
/// Pass [audioTracks] (resolved by `resolveAudioMix`) plus a [loadAudioBytes]
/// loader to mix audio: each track is staged into [sandbox] by
/// [stageResolvedAudioToSandbox] and its `amix` plan flows into the encode args,
/// scaled by [audioMasterVolume]. With no tracks (or no loader) the plan carries
/// `-an`, byte-identical to a video-only render. Audio rides the MP4 export only;
/// the other export modes ignore it.
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
  final controller = RenderController();
  final boundaryKey = GlobalKey();
  final shell = buildCaptureShell(
    composition: AspectScope(aspect: aspect, child: composition),
    boundaryKey: boundaryKey,
    controller: controller,
  );
  await pumpWidget(shell.tree);

  final digest = renderDigest(
    config: config,
    compositionKey: '$compositionKey-${aspect.name}',
    fluvieVersion: fluvieRenderVersion,
  );
  await sandbox.create();
  final sink = sandbox.openFrames(VideoEncoderService.framesFileName);
  try {
    await runFrameCaptureLoop(
      config: config,
      digest: digest,
      pump: (frame) async {
        controller.seek(frame);
        await pumpFrame();
      },
      boundaryKey: boundaryKey,
      sink: sink,
      capture: capture,
      onProgress: onProgress,
    );
  } finally {
    await sink.close();
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
    framesFileName: VideoEncoderService.framesFileName,
    outputFileName: encoder.outputNameFor(export),
    renderDigest: digest,
    ffmpegArgs: encoder.planEncodeArgs(
      config,
      audio: audioPlan?.tracks ?? const [],
      amix: audioPlan?.amix,
      export: export,
    ),
    posterFileName: posterFrame == null ? null : VideoEncoderService.posterFileName,
    posterArgs: posterFrame == null
        ? null
        : encoder.planPosterArgs(config, posterFrame: posterFrame),
  );
  await sandbox.writeText('manifest.json', jsonEncode(manifest.toJson()));
  return manifest;
}
