import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie/fluvie.dart';

import 'package:web_browser_studio/render/web_render_service_stub.dart'
    if (dart.library.js_interop) 'package:web_browser_studio/render/web_render_service_web.dart';

/// Renders a Fluvie composition to MP4 bytes in the browser and downloads it.
abstract interface class WebRenderService {
  /// Renders [composition] to MP4 bytes via ffmpeg.wasm.
  Future<Uint8List> render(
    Widget composition, {
    required Aspect aspect,
    required Duration duration,
    RenderProgressCallback? onProgress,
  });

  /// Hands [bytes] to the browser as a download named [filename].
  void download(Uint8List bytes, String filename);
}

/// The injected renderer: the real ffmpeg.wasm one in the browser, a throwing
/// stub off-web (overridden with a fake in tests).
final Provider<WebRenderService> webRenderServiceProvider = Provider<WebRenderService>(
  (ref) => createWebRenderService(),
);
