import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie_web_encoder/fluvie_web_encoder.dart';

import 'package:web_browser_studio/render/web_render_service.dart';

/// The browser renderer factory used when `dart.library.js_interop` is present.
WebRenderService createWebRenderService() => const WasmWebRenderService();

/// Renders fully in the browser with ffmpeg.wasm and downloads the result.
class WasmWebRenderService implements WebRenderService {
  /// Creates the in-browser renderer.
  const WasmWebRenderService();

  @override
  Future<Uint8List> render(
    Widget composition, {
    required Aspect aspect,
    required Duration duration,
    RenderProgressCallback? onProgress,
  }) {
    return WebVideoRenderer().render(
      composition: composition,
      aspect: aspect,
      duration: duration,
      longEdge: 480,
      audio: true,
      onProgress: onProgress,
    );
  }

  @override
  void download(Uint8List bytes, String filename) {
    downloadBytes(bytes, filename: filename);
    final ftyp = bytes.length >= 8 ? String.fromCharCodes(bytes.sublist(4, 8)) : '?';
    // The headless end-to-end harness reads this marker from the browser console.
    // ignore: avoid_print
    print('FLUVIE_E2E_RESULT ok bytes=${bytes.length} ftyp=$ftyp');
  }
}
