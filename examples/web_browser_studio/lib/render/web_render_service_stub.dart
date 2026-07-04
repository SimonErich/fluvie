import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';

import 'package:web_browser_studio/render/web_render_service.dart';

/// The off-web factory: in-browser rendering needs a browser.
WebRenderService createWebRenderService() => const UnsupportedWebRenderService();

/// A stub that explains in-browser rendering is web-only (kept so the package
/// still compiles on the host VM for unit tests, which inject a fake instead).
class UnsupportedWebRenderService implements WebRenderService {
  /// Creates the stub.
  const UnsupportedWebRenderService();

  @override
  Future<Uint8List> render(
    Widget composition, {
    required Aspect aspect,
    required Duration duration,
    RenderProgressCallback? onProgress,
  }) => throw UnsupportedError(
    'In-browser rendering is only available on the web.',
  );

  @override
  void download(Uint8List bytes, String filename) =>
      throw UnsupportedError('Downloads are only available on the web.');
}
