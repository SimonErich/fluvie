import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_web_encoder/src/offscreen_web_capture_host.dart';
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
/// Every dependency is injected so the orchestration is unit-testable: tests
/// pass a tester-backed [WebCaptureHost] and a [WebVideoEncoder] over a fake
/// runtime. This release renders video only (no audio mix yet).
final class WebVideoRenderer {
  /// Creates a renderer; the defaults target a real browser.
  WebVideoRenderer({WebVideoEncoder? encoder, WebCaptureHostFactory? hostFactory})
    : _encoder = encoder ?? WebVideoEncoder(),
      _hostFactory = hostFactory ?? _defaultHostFactory;

  final WebVideoEncoder _encoder;
  final WebCaptureHostFactory _hostFactory;

  /// Renders [composition] for [aspect] over [duration] and returns the MP4
  /// bytes (deliver them as a browser download or upload).
  ///
  /// [longEdge] sets the canvas's longer side; [fps] and [duration] set the
  /// frame count (`duration * fps`, at least one). [export] selects GIF or
  /// transparent WebM instead of H.264; [posterFrame] adds a poster still;
  /// [onProgress] observes the capture loop. Throws an [ArgumentError] for a
  /// non-positive [duration] or [fps], and a `FluvieEncodeException` when
  /// ffmpeg.wasm fails.
  Future<Uint8List> render({
    required Widget composition,
    required Aspect aspect,
    required Duration duration,
    int fps = 30,
    int longEdge = 1080,
    String compositionKey = 'render',
    Export? export,
    int? posterFrame,
    ProgressCallback? onProgress,
  }) async {
    final frameCount = _frameCountFor(duration, fps);
    final size = aspect.sizeFor(longEdge);
    final sandbox = MemoryRenderSandbox();
    final host = _hostFactory(Size(size.width.toDouble(), size.height.toDouble()));
    try {
      final manifest = await renderToSandbox(
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
        onProgress: onProgress,
      );
      return _encoder.encode(manifest: manifest, sandbox: sandbox);
    } finally {
      await host.dispose();
    }
  }

  static int _frameCountFor(Duration duration, int fps) {
    if (fps <= 0) throw ArgumentError.value(fps, 'fps', 'must be positive');
    if (duration <= Duration.zero) {
      throw ArgumentError.value(duration.toString(), 'duration', 'must be positive');
    }
    final frames = (duration.inMicroseconds * fps / Duration.microsecondsPerSecond).round();
    return frames < 1 ? 1 : frames;
  }

  // coverage:ignore-line: constructs the engine-backed host, exercised only in a browser.
  static WebCaptureHost _defaultHostFactory(Size size) => OffscreenWebCaptureHost(size);
}
