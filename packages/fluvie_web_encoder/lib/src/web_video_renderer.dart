import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie_web_encoder/src/clip_decoder.dart';
import 'package:fluvie_web_encoder/src/fluvie_web_stage.dart';
import 'package:fluvie_web_encoder/src/png_frame_encoder.dart';
import 'package:fluvie_web_encoder/src/web_audio_materializer.dart';
import 'package:fluvie_web_encoder/src/web_capture_host.dart';
import 'package:fluvie_web_encoder/src/web_video_encoder.dart';

part 'web_video_renderer_policy.dart';
part 'web_video_renderer_capture.dart';

/// Builds the off-screen [WebCaptureHost] for a render at [size] logical pixels.
typedef WebCaptureHostFactory = WebCaptureHost Function(Size size);

/// Renders a Fluvie composition to an MP4 entirely in the browser.
///
/// It runs Fluvie's deterministic capture loop into an off-screen surface (so
/// the page never flickers), writing the frames into an in-memory sandbox, then
/// encodes them with ffmpeg.wasm through a [WebVideoEncoder]. Because ffmpeg.wasm
/// **is** FFmpeg, the same `Video` and the full feature set (H.264, GIF,
/// transparent WebM via [Export]) render exactly as on the desktop, with the
/// bytes never leaving the browser.
///
/// Audio is opt-in: pass `audio: true` to [render] to mix and mux a `Video`'s
/// declared `Audio` tracks (asset or allowlisted network audio); by default a
/// `Video` with audio renders silent and (unless silenced) warns through
/// the injected warning sink. Every dependency is injected so the orchestration is
/// unit-testable: tests pass a tester-backed [WebCaptureHost], a [WebVideoEncoder]
/// over a fake runtime, and a fake [WebAudioMaterializer].
final class WebVideoRenderer implements VideoRenderer<Uint8List>, RequestVideoRenderer<Uint8List> {
  /// Creates a renderer; the defaults target a real browser.
  WebVideoRenderer({
    WebVideoEncoder? encoder,
    WebCaptureHostFactory? hostFactory,
    WebAudioMaterializer? audioMaterializer,
    WebClipDecoder? clipDecoder,
    FrameEncoder? frameEncoder,
    void Function(String message)? onWarning,
    this.mediaResolver,
    this.networkAllowlist,
    this.cancellation,
  }) : _hostFactory = hostFactory ?? _defaultHostFactory,
       // coverage:ignore-line the _defaultEncoder default only runs in a browser
       _encoder = encoder ?? _defaultEncoder(),
       // coverage:ignore-line the default materializer reads rootBundle only in a browser
       _audioMaterializer = audioMaterializer ?? BundleWebAudioMaterializer(),
       _clipDecoder = clipDecoder ?? createWebClipDecoder(),
       _frameEncoder = frameEncoder ?? encodeFramePng,
       _onWarning = onWarning ?? _defaultWarn;

  /// The injected media resolver, or null to build (and dispose) one per
  /// [render] from `mediaResolverProvider` — a `WebImageMediaResolver` on web,
  /// which paints declared image media (asset, network, memory) and clips
  /// through [_clipDecoder].
  final MediaResolver? mediaResolver;

  /// Restricts which hosts network media (images) may be fetched from. Applied
  /// to the per-render resolver when none is injected; ignored when
  /// [mediaResolver] is provided (configure the allowlist on it instead).
  final NetworkAllowlist? networkAllowlist;

  /// Cancellation shared with the export queue; checked between captures.
  final RenderCancellation? cancellation;

  /// Sink for renderer warnings (for example a `Video` declares audio but
  /// in-browser audio is off). Defaults to [debugPrint]; inject one to route
  /// warnings (a test captures them here).
  final void Function(String message) _onWarning;

  final WebVideoEncoder _encoder;
  final WebCaptureHostFactory _hostFactory;
  final WebAudioMaterializer _audioMaterializer;

  /// Decodes clip frames for the per-render resolver (WebCodecs in the browser,
  /// a fail-on-use stub on the VM). Ignored when [mediaResolver] is injected.
  final WebClipDecoder _clipDecoder;

  /// Compresses each captured frame to PNG so the render stages bounded-memory
  /// per-frame files instead of one giant raw buffer. Defaults to the engine PNG
  /// codec; a test injects a fake to avoid a real engine.
  final FrameEncoder _frameEncoder;

  /// Renders [composition] for [aspect] over [duration] and returns the MP4
  /// bytes (deliver them as a browser download or upload).
  ///
  /// [longEdge] sets the canvas's longer side; [fps] and [duration] set the
  /// frame count (`duration * fps`, at least one). [export] selects GIF or
  /// transparent WebM instead of H.264; [posterFrame] adds a poster still;
  /// [onProgress] reports per-frame capture progress then the encoding and
  /// complete phases.
  ///
  /// When [composition] is a `Video` with declared `Audio`, pass [audio] `true`
  /// to mix and mux those tracks; left `false` the render is silent and, unless
  /// [warnOnDroppedAudio] is `false`, the injected warning sink is called once. Audio rides the
  /// MP4 export only — a GIF or transparent [export] drops it (also warned).
  ///
  /// Throws an [ArgumentError] for a non-positive [duration] or [fps], and a
  /// `FluvieEncodeException` when ffmpeg.wasm fails.
  @override
  Future<Uint8List> render({
    required Widget composition,
    required Aspect aspect,
    required Duration duration,
    int fps = VideoDefaults.fps,
    int longEdge = 1080,
    bool audio = false,
    bool warnOnDroppedAudio = true,
    String compositionKey = 'render',
    Export? export,
    int? posterFrame,
    RenderProgressCallback? onProgress,
  }) async {
    final size = aspect.sizeFor(longEdge);
    return renderRequest(
      VideoRenderRequest(
        composition: composition,
        width: size.width,
        height: size.height,
        fps: fps,
        frameCount: frameCountFor(duration, fps),
        aspect: aspect,
        export: export,
        posterFrame: posterFrame,
        audio: audio,
        warnOnDroppedAudio: warnOnDroppedAudio,
        compositionKey: compositionKey,
        onProgress: onProgress,
        cancellation: cancellation,
      ),
    );
  }

  @override
  RenderCapabilities get capabilities => RenderCapabilities.browser;

  @override
  Future<Uint8List> renderRequest(VideoRenderRequest request) => _renderRequest(request);
}
