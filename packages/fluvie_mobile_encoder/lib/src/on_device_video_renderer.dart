import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie_mobile_encoder/src/capture_host.dart';
import 'package:fluvie_mobile_encoder/src/method_channel_mobile_video_encoder.dart';
import 'package:fluvie_mobile_encoder/src/mobile_audio_materializer.dart';
import 'package:fluvie_mobile_encoder/src/mobile_audio_track.dart';
import 'package:fluvie_mobile_encoder/src/mobile_bitrate.dart';
import 'package:fluvie_mobile_encoder/src/mobile_encode_request.dart';
import 'package:fluvie_mobile_encoder/src/mobile_video_codec.dart';
import 'package:fluvie_mobile_encoder/src/mobile_video_encoder.dart';
import 'package:fluvie_mobile_encoder/src/native_frame_extraction_service.dart';
import 'package:fluvie_mobile_encoder/src/native_pcm_decoder.dart';
import 'package:fluvie_mobile_encoder/src/native_poster.dart';
import 'package:fluvie_mobile_encoder/src/native_video_probe_service.dart';
import 'package:fluvie_mobile_encoder/src/offscreen_capture_host.dart';
import 'package:riverpod/riverpod.dart';

part 'on_device_video_renderer_capture.dart';
part 'on_device_video_renderer_pipeline.dart';

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
/// (unless silenced) [render] warns through the injected warning sink.
final class OnDeviceVideoRenderer implements VideoRenderer<File>, RequestVideoRenderer<File> {
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
    void Function(String message)? onWarning,
    this.mediaResolver,
    this.networkAllowlist,
    this.cancellation,
    this.pcmDecoder,
  }) : _encoder = encoder ?? const MethodChannelMobileVideoEncoder(),
       _hostFactory = hostFactory ?? _defaultHostFactory,
       _sandboxFactory = sandboxFactory ?? _defaultSandboxFactory,
       _service = service ?? RenderService(capture: const RepaintBoundaryCaptureService()),
       // ignore: prefer_initializing_formals — preserve the established public injection parameter.
       _audioMaterializer = audioMaterializer,
       _onWarning = onWarning ?? _defaultWarn;

  /// Sink for renderer warnings (e.g. a `Video` declares audio but on-device
  /// audio is off). Defaults to [debugPrint]; inject one to route warnings (a
  /// test captures them here).
  final void Function(String message) _onWarning;

  // coverage:ignore-line the default sink runs only when no onWarning is injected which tests always do
  static void _defaultWarn(String message) => debugPrint('fluvie_mobile_encoder: $message');

  final MobileVideoEncoder _encoder;
  final CaptureHostFactory _hostFactory;
  final SandboxFactory _sandboxFactory;
  final RenderService _service;
  final MobileAudioMaterializer? _audioMaterializer;

  /// The injected media resolver, or null to build (and dispose) one per
  /// [render] from `mediaResolverProvider`.
  final MediaResolver? mediaResolver;

  /// Restricts which hosts network media (images) may be fetched from. Applied
  /// to the per-render resolver when none is injected; ignored when
  /// [mediaResolver] is provided (configure the allowlist on it instead).
  final NetworkAllowlist? networkAllowlist;

  /// Stops capture before another frame or encode stage is started.
  /// Native encode already in progress is allowed to finish, then discarded.
  final RenderCancellation? cancellation;

  /// Optional PCM backend used by both beat and frequency analysis.
  /// The default uses native compressed-audio decoding, without FFmpeg.
  final PcmDecoder? pcmDecoder;

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
  /// unless [warnOnDroppedAudio] is `false`, the injected warning sink is called once. Audio is
  /// resolved with the renderer's `MobileAudioMaterializer`.
  ///
  /// Throws an [ArgumentError] for a non-positive [duration] or [fps], and a
  /// `FluvieMobileEncoderException` when the device encoder fails.
  @override
  Future<File> render({
    required Widget composition,
    required Aspect aspect,
    required Duration duration,
    int fps = VideoDefaults.fps,
    int longEdge = VideoDefaults.longEdge,
    MobileVideoCodec? codec,
    int? bitRate,
    bool audio = false,
    bool warnOnDroppedAudio = true,
    String compositionKey = 'render',
    RenderProgressCallback? onProgress,
    File? outputFile,
  }) async {
    final authored = compositionVideo(composition)?.export;
    if (authored != null) {
      try {
        final size = aspect.sizeFor(longEdge);
        VideoRenderRequest(
          composition: composition,
          width: size.width,
          height: size.height,
          fps: fps,
          frameCount: frameCountFor(duration, fps),
          export: authored,
          audio: audio,
        ).validateCapabilities(capabilities);
      } on FluvieCapabilityException catch (error) {
        throw UnsupportedError(error.message);
      }
    }
    final size = aspect.sizeFor(longEdge);
    return _renderRequest(
      VideoRenderRequest(
        composition: composition,
        width: size.width,
        height: size.height,
        fps: fps,
        frameCount: frameCountFor(duration, fps),
        aspect: aspect,
        audio: audio,
        warnOnDroppedAudio: warnOnDroppedAudio,
        compositionKey: compositionKey,
        onProgress: onProgress,
        cancellation: cancellation,
      ),
      codec: codec,
      bitRate: bitRate,
      outputFile: outputFile,
    );
  }

  @override
  RenderCapabilities get capabilities => RenderCapabilities.mobile;

  @override
  Future<File> renderRequest(VideoRenderRequest request) => _renderRequest(request);

  // coverage:ignore-line constructs the engine backed host exercised only on a device
  static CaptureHost _defaultHostFactory(Size size) => OffscreenCaptureHost(size);

  static Future<Directory> _defaultSandboxFactory() =>
      Directory.systemTemp.createTemp('fluvie_mobile_render_');
}
