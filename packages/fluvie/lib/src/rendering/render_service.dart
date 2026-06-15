import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart' show GlobalKey;
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/export.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/rendering/capture/frame_capture_service.dart';
import 'package:fluvie/src/rendering/capture/render_manifest.dart';
import 'package:fluvie/src/rendering/encoding/audio_graph_nodes.dart';
import 'package:fluvie/src/rendering/encoding/content_hash.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_provider.dart';
import 'package:fluvie/src/rendering/encoding/frame_cache.dart';
import 'package:fluvie/src/rendering/encoding/video_encoder_service.dart';
import 'package:fluvie/src/rendering/no_media_resolver.dart';
import 'package:fluvie/src/rendering/render_config.dart';

part 'render_frame_loop.dart';

/// Pumps the tree to frame `n` and returns once that frame is fully built —
/// the host (a widget test, the capture harness) owns the pumping mechanics.
typedef FramePump = Future<void> Function(int frame);

/// Reports capture progress: [completed] of [total] frames are written.
///
/// Called once per frame after it is appended (a cache hit counts too), so the
/// count rises monotonically from `1` to `total`. Purely observational — it is
/// driven by the deterministic frame loop, reads no wall-clock, and never
/// affects a frame's bytes; a host wires it to a UI or a progress file.
typedef ProgressCallback = void Function(int completed, int total);

/// The encoder audio lanes a render contributes: the per-track [FfmpegAudioNode]s
/// and the [FfmpegAudioMix] that combines them (`null` mix = no audio).
typedef AudioMixLanes = ({List<FfmpegAudioNode> nodes, FfmpegAudioMix? amix});

/// Stages the pre-resolved audio into the render `sandbox` and returns its
/// encoder lanes. Injected so `rendering` stays independent
/// of the `audio` feature layer: the shell wires the audio layer's
/// `stageAudioMix`, tests pass a fake.
typedef AudioMixStager =
    Future<AudioMixLanes> Function({required MediaResolver resolver, required Directory sandbox});

/// Drives the deterministic capture pipeline: pre-resolve media, loop the
/// frames (cache → pump → capture → append), then write the manifest **last**
/// as the completion signal.
///
/// The frame loop is the only clock: every frame is explicitly pumped via the
/// injected [FramePump] before its pixels are read, media is pre-resolved
/// before the first frame, and frames whose render digest is already cached
/// replay from disk without pumping at all.
final class RenderService {
  /// Creates a render service over the injected seams.
  ///
  /// [media] defaults to the media-less [NoMediaResolver]; pass `cache` to
  /// enable frame caching (combined with `RenderConfig.cacheEnabled`).
  RenderService({
    required this._capture,
    this.media = const NoMediaResolver(),
    this._cache,
    this.encoder = const VideoEncoderService(),
  });

  /// The fluvie version baked into every render digest (kept in lockstep with
  /// `pubspec.yaml`); a version bump invalidates all cached frames.
  static const String _fluvieVersion = '0.1.0';

  final FrameCaptureService _capture;
  final FrameCache? _cache;

  /// Resolves media before the frame loop and serves it synchronously during.
  final MediaResolver media;

  /// Plans the encode arguments embedded in the manifest.
  final VideoEncoderService encoder;

  /// Captures `config.frameCount` frames into `outDir/frames.rgba` and writes
  /// `outDir/manifest.json` **last**, returning the parsed manifest.
  ///
  /// Order of operations: `media.preResolveAll(mediaSources)` → frame loop
  /// (`config.startFrame` ascending; per frame: cache lookup by digest+index,
  /// else [pump] then capture under [boundaryKey], append to the frames file,
  /// cache store) → manifest write. The manifest embeds the complete encode
  /// argument array from [VideoEncoderService.planEncodeArgs].
  Future<RenderManifest> captureToDirectory({
    required RenderConfig config,
    required Directory outDir,
    required FramePump pump,
    required GlobalKey boundaryKey,
    required String compositionKey,
    Iterable<MediaSource> mediaSources = const [],
    Iterable<AudioSource> audioSources = const [],
    AudioMixStager? stageAudio,
    Export? export,
    int? posterFrame,
    ProgressCallback? onProgress,
  }) async {
    await media.preResolveAll(mediaSources);
    await media.preResolveAudio(audioSources);
    final digest = renderDigest(
      config: config,
      compositionKey: compositionKey,
      fluvieVersion: _fluvieVersion,
    );
    await outDir.create(recursive: true);
    final lanes = stageAudio == null
        ? const (nodes: <FfmpegAudioNode>[], amix: null)
        : await stageAudio(resolver: media, sandbox: outDir);
    final sink = File('${outDir.path}/${VideoEncoderService.framesFileName}').openWrite();
    try {
      await _runFrameLoop(
        config: config,
        digest: digest,
        pump: pump,
        boundaryKey: boundaryKey,
        sink: sink,
        capture: _capture,
        cache: _cache,
        onProgress: onProgress,
      );
    } finally {
      await sink.close();
    }
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
        audio: lanes.nodes,
        amix: lanes.amix,
        export: export,
      ),
      posterFileName: posterFrame == null ? null : VideoEncoderService.posterFileName,
      posterArgs: posterFrame == null
          ? null
          : encoder.planPosterArgs(config, posterFrame: posterFrame),
    );
    await File(
      '${outDir.path}/manifest.json',
    ).writeAsString(jsonEncode(manifest.toJson()), flush: true);
    return manifest;
  }

  /// [captureToDirectory] followed by an in-process encode through [provider],
  /// returning the encoded `outDir/out.mp4`.
  Future<File> render({
    required RenderConfig config,
    required Directory outDir,
    required FramePump pump,
    required GlobalKey boundaryKey,
    required String compositionKey,
    required FfmpegProvider provider,
    Iterable<MediaSource> mediaSources = const [],
    Iterable<AudioSource> audioSources = const [],
    AudioMixStager? stageAudio,
    Export? export,
    int? posterFrame,
    ProgressCallback? onProgress,
  }) async {
    final manifest = await captureToDirectory(
      config: config,
      outDir: outDir,
      pump: pump,
      boundaryKey: boundaryKey,
      compositionKey: compositionKey,
      mediaSources: mediaSources,
      audioSources: audioSources,
      stageAudio: stageAudio,
      export: export,
      posterFrame: posterFrame,
      onProgress: onProgress,
    );
    await provider.encode(args: manifest.ffmpegArgs, sandbox: outDir);
    final posterArgs = manifest.posterArgs;
    if (posterArgs != null) {
      await provider.encode(args: posterArgs, sandbox: outDir);
    }
    return File('${outDir.path}/${manifest.outputFileName}');
  }
}
