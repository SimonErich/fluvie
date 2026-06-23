import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_web_encoder/src/clip_decoder.dart';
import 'package:fluvie_web_encoder/src/fluvie_web_stage.dart';
import 'package:fluvie_web_encoder/src/png_frame_encoder.dart';
import 'package:fluvie_web_encoder/src/web_audio_materializer.dart';
import 'package:fluvie_web_encoder/src/web_capture_host.dart';
import 'package:fluvie_web_encoder/src/web_video_encoder.dart';

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
/// [onWarning]. Every dependency is injected so the orchestration is
/// unit-testable: tests pass a tester-backed [WebCaptureHost], a [WebVideoEncoder]
/// over a fake runtime, and a fake [WebAudioMaterializer].
final class WebVideoRenderer {
  /// Creates a renderer; the defaults target a real browser.
  WebVideoRenderer({
    WebVideoEncoder? encoder,
    WebCaptureHostFactory? hostFactory,
    WebAudioMaterializer? audioMaterializer,
    WebClipDecoder? clipDecoder,
    FrameEncoder? frameEncoder,
    this.mediaResolver,
    this.networkAllowlist,
  }) : _hostFactory = hostFactory ?? _defaultHostFactory,
       // coverage:ignore-line: the `?? _defaultEncoder()` default only runs in a browser.
       _encoder = encoder ?? _defaultEncoder(),
       // coverage:ignore-line: the default materializer reads rootBundle, only in a browser.
       _audioMaterializer = audioMaterializer ?? BundleWebAudioMaterializer(),
       _clipDecoder = clipDecoder ?? createWebClipDecoder(),
       _frameEncoder = frameEncoder ?? encodeFramePng;

  /// The injected media resolver, or null to build (and dispose) one per
  /// [render] from `mediaResolverProvider` — a `WebImageMediaResolver` on web,
  /// which paints declared image media (asset, network, memory) and clips
  /// through [_clipDecoder].
  final MediaResolver? mediaResolver;

  /// Restricts which hosts network media (images) may be fetched from. Applied
  /// to the per-render resolver when none is injected; ignored when
  /// [mediaResolver] is provided (configure the allowlist on it instead).
  final NetworkAllowlist? networkAllowlist;

  /// Sink for renderer warnings (for example a `Video` declares audio but
  /// in-browser audio is off). Defaults to [debugPrint]; replace it to route
  /// warnings (a test captures them here).
  static void Function(String message) onWarning = _defaultWarn;

  // coverage:ignore-line: the default sink runs only when onWarning is not overridden, which tests always do.
  static void _defaultWarn(String message) => debugPrint('fluvie_web_encoder: $message');

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
  /// [warnOnDroppedAudio] is `false`, [onWarning] is called once. Audio rides the
  /// MP4 export only — a GIF or transparent [export] drops it (also warned).
  ///
  /// Throws an [ArgumentError] for a non-positive [duration] or [fps], and a
  /// `FluvieEncodeException` when ffmpeg.wasm fails.
  Future<Uint8List> render({
    required Widget composition,
    required Aspect aspect,
    required Duration duration,
    int fps = 30,
    int longEdge = 1080,
    bool audio = false,
    bool warnOnDroppedAudio = true,
    String compositionKey = 'render',
    Export? export,
    int? posterFrame,
    RenderProgressCallback? onProgress,
  }) async {
    final frameCount = frameCountFor(duration, fps);
    final size = aspect.sizeFor(longEdge);
    final sandbox = MemoryRenderSandbox();
    final host = _hostFactory(Size(size.width.toDouble(), size.height.toDouble()));
    final scope = resolverScope(
      mediaResolver,
      networkAllowlist: networkAllowlist,
      clipDecoder: _clipDecoder,
    );
    try {
      // Resolve audio inside the try so a throw here still disposes the host.
      final mix = _audioFor(
        composition,
        encode: audio,
        warn: warnOnDroppedAudio,
        export: export,
        fps: fps,
        frameCount: frameCount,
      );
      final manifest = await runStage(
        RenderPhase.capturing,
        () => renderToSandbox(
          composition: composition,
          aspect: aspect,
          frameCount: frameCount,
          sandbox: sandbox,
          capture: const RepaintBoundaryCaptureService(),
          pumpWidget: host.mount,
          pumpFrame: host.pumpFrame,
          longEdge: longEdge,
          fps: fps,
          compositionKey: compositionKey,
          export: export,
          posterFrame: posterFrame,
          onProgress: (completed, total) => onProgress?.call(
            RenderProgress(
              RenderPhase.capturing,
              completedFrames: completed,
              totalFrames: total,
              compositionKey: compositionKey,
            ),
          ),
          audioTracks: mix.tracks,
          loadAudioBytes: _audioMaterializer.materialize,
          audioMasterVolume: mix.masterVolume,
          resolver: scope.resolver,
          frameEncoder: _frameEncoder,
        ),
      );
      onProgress?.call(RenderProgress(RenderPhase.encoding, compositionKey: compositionKey));
      final bytes = await runStage(
        RenderPhase.encoding,
        () => _encoder.encode(manifest: manifest, sandbox: sandbox),
      );
      onProgress?.call(RenderProgress(RenderPhase.complete, compositionKey: compositionKey));
      return bytes;
    } finally {
      await runGuarded([
        host.dispose,
        scope.dispose,
      ], (error, _) => onWarning('Cleanup after render failed: $error'));
    }
  }

  /// Resolves [composition]'s audio into resolved tracks to stage, or none.
  ///
  /// A non-`Video` or audio-less composition yields no tracks. With audio present
  /// but [encode] `false`, it warns once (when [warn]) and yields none; a non-MP4
  /// [export] cannot carry audio, so it warns and yields none too.
  ({List<ResolvedAudioTrack> tracks, double masterVolume}) _audioFor(
    Widget composition, {
    required bool encode,
    required bool warn,
    required Export? export,
    required int fps,
    required int frameCount,
  }) {
    const none = (tracks: <ResolvedAudioTrack>[], masterVolume: 1.0);
    if (composition is! Video) return none;
    final mix = resolveAudioMix(video: composition, fps: fps, totalFrames: frameCount);
    if (mix.isEmpty) return none;
    if (!encode) {
      if (warn) {
        onWarning(
          'This Video declares ${mix.tracks.length} audio track(s), but in-browser '
          'audio is off, so the MP4 will be silent. Pass audio: true to encode it, '
          'or warnOnDroppedAudio: false to silence this warning.',
        );
      }
      return none;
    }
    if (export != null && export.mode != ExportMode.mp4) {
      if (warn) {
        onWarning(
          'Audio is only muxed into MP4 renders; this ${export.mode.name} export '
          'drops the ${mix.tracks.length} declared audio track(s).',
        );
      }
      return none;
    }
    return (tracks: mix.tracks, masterVolume: mix.masterVolume);
  }

  // coverage:ignore-line: binds to the live FluvieWebStage, exercised only in a browser.
  static WebCaptureHost _defaultHostFactory(Size size) => FluvieWebStage.hostFor(size);

  // coverage:ignore-line: constructs the default ffmpeg.wasm encoder, only valid in a browser.
  static WebVideoEncoder _defaultEncoder() => WebVideoEncoder();
}
