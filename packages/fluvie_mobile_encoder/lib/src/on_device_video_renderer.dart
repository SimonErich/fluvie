import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_mobile_encoder/src/capture_host.dart';
import 'package:fluvie_mobile_encoder/src/method_channel_mobile_video_encoder.dart';
import 'package:fluvie_mobile_encoder/src/mobile_audio_materializer.dart';
import 'package:fluvie_mobile_encoder/src/mobile_audio_track.dart';
import 'package:fluvie_mobile_encoder/src/mobile_bitrate.dart';
import 'package:fluvie_mobile_encoder/src/mobile_encode_request.dart';
import 'package:fluvie_mobile_encoder/src/mobile_video_codec.dart';
import 'package:fluvie_mobile_encoder/src/mobile_video_encoder.dart';
import 'package:fluvie_mobile_encoder/src/offscreen_capture_host.dart';

/// Builds the off-screen [CaptureHost] for a render at [size] logical pixels.
typedef CaptureHostFactory = CaptureHost Function(Size size);

/// Opens a fresh sandbox directory for one render's frames and output.
typedef SandboxFactory = Future<Directory> Function();

/// Renders a Fluvie composition to an MP4 entirely on the device.
///
/// It runs Fluvie's deterministic capture loop into an off-screen surface (so
/// the live UI never flickers), writing `frames.rgba` into a sandbox, then
/// encodes those frames with the platform's hardware video encoder through a
/// [MobileVideoEncoder]. No FFmpeg, no bundled binary, no network: the frames
/// never leave the device.
///
/// Every dependency is injected so the orchestration is unit-testable. Audio is
/// opt-in: pass `audio: true` to [render] to decode, mix, and mux a `Video`'s
/// declared `Audio` tracks; by default a `Video` with audio renders silent and
/// (unless silenced) [render] warns through [onWarning].
final class OnDeviceVideoRenderer {
  /// Creates a renderer over its seams; the defaults target a real device.
  ///
  /// [mediaResolver] resolves a composition's `Image`/`Clip` sources; when left
  /// null a fresh `MediaRepository` is built (and disposed) per [render] from
  /// `mediaResolverProvider`. Pass one to inject a fake in a test.
  OnDeviceVideoRenderer({
    MobileVideoEncoder? encoder,
    CaptureHostFactory? hostFactory,
    SandboxFactory? sandboxFactory,
    RenderService? service,
    MobileAudioMaterializer? audioMaterializer,
    this.mediaResolver,
    this.networkAllowlist,
  }) : _encoder = encoder ?? const MethodChannelMobileVideoEncoder(),
       _hostFactory = hostFactory ?? _defaultHostFactory,
       _sandboxFactory = sandboxFactory ?? _defaultSandboxFactory,
       _service = service ?? RenderService(capture: const RepaintBoundaryCaptureService()),
       _audioMaterializer = audioMaterializer ?? BundleAudioMaterializer();

  /// Sink for renderer warnings (e.g. a `Video` declares audio but on-device
  /// audio is off). Defaults to [debugPrint]; replace it to route warnings (a
  /// test captures them here).
  static void Function(String message) onWarning = _defaultWarn;

  // coverage:ignore-line: the default sink runs only when onWarning is not overridden, which tests always do.
  static void _defaultWarn(String message) => debugPrint('fluvie_mobile_encoder: $message');

  final MobileVideoEncoder _encoder;
  final CaptureHostFactory _hostFactory;
  final SandboxFactory _sandboxFactory;
  final RenderService _service;
  final MobileAudioMaterializer _audioMaterializer;

  /// The injected media resolver, or null to build (and dispose) one per
  /// [render] from `mediaResolverProvider`.
  final MediaResolver? mediaResolver;

  /// Restricts which hosts network media (images) may be fetched from. Applied
  /// to the per-render resolver when none is injected; ignored when
  /// [mediaResolver] is provided (configure the allowlist on it instead).
  final NetworkAllowlist? networkAllowlist;

  /// Renders [composition] for [aspect] over [duration] to an MP4 file.
  ///
  /// [longEdge] sets the canvas's longer side in pixels (the shorter side is
  /// derived from [aspect]); [fps] and [duration] set the frame count
  /// (`duration * fps`, at least one frame). [codec] and [bitRate] (defaulted by
  /// [defaultBitRate]) configure the encoder, and [onProgress] observes the
  /// capturing → encoding → complete phases. By default the MP4 is written into a
  /// fresh sandbox; pass [outputFile] to have the encoder write it there instead,
  /// and that file is returned.
  ///
  /// When [composition] is a `Video` with declared `Audio`, pass [audio] `true`
  /// to decode, mix, and mux those tracks; left `false` the render is silent and,
  /// unless [warnOnDroppedAudio] is `false`, [onWarning] is called once. Audio is
  /// resolved with the renderer's `MobileAudioMaterializer`.
  ///
  /// Throws an [ArgumentError] for a non-positive [duration] or [fps], and a
  /// `FluvieMobileEncoderException` when the device encoder fails.
  Future<File> render({
    required Widget composition,
    required Aspect aspect,
    required Duration duration,
    int fps = 30,
    int longEdge = 1920,
    MobileVideoCodec codec = MobileVideoCodec.h264,
    int? bitRate,
    bool audio = false,
    bool warnOnDroppedAudio = true,
    String compositionKey = 'render',
    RenderProgressCallback? onProgress,
    File? outputFile,
  }) async {
    final frameCount = frameCountFor(duration, fps);
    final size = aspect.sizeFor(longEdge);
    final sandbox = await _sandboxFactory();
    final host = _hostFactory(Size(size.width.toDouble(), size.height.toDouble()));
    final scope = resolverScope(mediaResolver, networkAllowlist: networkAllowlist);
    try {
      onProgress?.call(RenderProgress(RenderPhase.capturing, compositionKey: compositionKey));
      final captured = await runStage(
        RenderPhase.capturing,
        () => _captureToSandbox(
          composition: composition,
          aspect: aspect,
          frameCount: frameCount,
          outDir: sandbox,
          service: _service,
          pumpWidget: host.mount,
          pumpFrame: host.pumpFrame,
          longEdge: longEdge,
          fps: fps,
          compositionKey: compositionKey,
          resolver: scope.resolver,
        ),
      );
      final manifest = captured.manifest;
      final mix = await _audioFor(
        composition,
        encode: audio,
        warn: warnOnDroppedAudio,
        fps: fps,
        frameCount: frameCount,
      );
      final outputPath = outputFile?.path ?? '${sandbox.path}/${manifest.outputFileName}';
      onProgress?.call(RenderProgress(RenderPhase.encoding, compositionKey: compositionKey));
      await runStage(
        RenderPhase.encoding,
        () => _encoder.encode(
          MobileEncodeRequest(
            framesPath: '${sandbox.path}/${manifest.framesFileName}',
            outputPath: outputPath,
            width: manifest.width,
            height: manifest.height,
            fps: manifest.fps,
            frameCount: manifest.frameCount,
            bitRate:
                bitRate ??
                defaultBitRate(width: manifest.width, height: manifest.height, fps: manifest.fps),
            codec: codec,
            audioTracks: mix.tracks,
            audioMasterVolume: mix.masterVolume,
          ),
        ),
      );
      onProgress?.call(RenderProgress(RenderPhase.complete, compositionKey: compositionKey));
      return File(outputPath);
    } finally {
      await runGuarded([
        host.dispose,
        scope.dispose,
      ], (error, _) => onWarning('Cleanup after render failed: $error'));
    }
  }

  /// Resolves [composition]'s audio into materialized [MobileAudioTrack]s.
  ///
  /// A non-`Video` or audio-less composition yields no tracks. With audio present
  /// but [encode] `false`, it warns once (when [warn]) and yields no tracks;
  /// otherwise it materializes every track's source through the renderer's
  /// materializer.
  Future<({List<MobileAudioTrack> tracks, double masterVolume})> _audioFor(
    Widget composition, {
    required bool encode,
    required bool warn,
    required int fps,
    required int frameCount,
  }) async {
    if (composition is! Video) return (tracks: const <MobileAudioTrack>[], masterVolume: 1.0);
    final mix = resolveAudioMix(video: composition, fps: fps, totalFrames: frameCount);
    if (mix.isEmpty) return (tracks: const <MobileAudioTrack>[], masterVolume: 1.0);
    if (!encode) {
      if (warn) {
        onWarning(
          'This Video declares ${mix.tracks.length} audio track(s), but on-device '
          'audio is off, so the MP4 will be silent. Pass audio: true to encode it, '
          'or warnOnDroppedAudio: false to silence this warning.',
        );
      }
      return (tracks: const <MobileAudioTrack>[], masterVolume: 1.0);
    }
    return (
      tracks: [
        for (final track in mix.tracks)
          MobileAudioTrack.fromResolved(
            track,
            path: await _audioMaterializer.materialize(track.source),
          ),
      ],
      masterVolume: mix.masterVolume,
    );
  }

  // coverage:ignore-line: constructs the engine-backed host, exercised only on a device.
  static CaptureHost _defaultHostFactory(Size size) => OffscreenCaptureHost(size);

  static Future<Directory> _defaultSandboxFactory() =>
      Directory.systemTemp.createTemp('fluvie_mobile_render_');
}

/// Fluvie's capture entry, wrapped at library scope so
/// [OnDeviceVideoRenderer.render] can call it without the method name shadowing
/// the free function. Capture stages a silent FFmpeg lane; the renderer mixes
/// and muxes audio natively after capture (see [OnDeviceVideoRenderer._audioFor]).
Future<RenderAspectResult> _captureToSandbox({
  required Widget composition,
  required Aspect aspect,
  required int frameCount,
  required Directory outDir,
  required RenderService service,
  required ShellMount pumpWidget,
  required ShellFramePump pumpFrame,
  required int longEdge,
  required int fps,
  required String compositionKey,
  required MediaResolver resolver,
}) => render(
  composition: composition,
  aspect: aspect,
  frameCount: frameCount,
  outDir: outDir,
  service: service,
  pumpWidget: pumpWidget,
  pumpFrame: pumpFrame,
  longEdge: longEdge,
  fps: fps,
  compositionKey: compositionKey,
  stageAudio: _silentAudio,
  resolver: resolver,
);

Future<AudioMixLanes> _silentAudio({
  required MediaResolver resolver,
  required Directory sandbox,
}) async => (nodes: const <Never>[], amix: null);
