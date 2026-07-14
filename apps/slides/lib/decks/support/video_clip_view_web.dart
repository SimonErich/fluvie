import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// The web player: one platform-view factory per asset (idempotent across
/// rebuilds), an HTML `video` with controls and sound. Autoplay is left to
/// the play button — browsers block sounding autoplay anyway.
// coverage:ignore-start browser bindings need a real DOM
Widget buildVideoClipView(String assetPath, String label) {
  final viewType = 'slides-video-clip::$assetPath';
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
    // Bundled assets are served under assets/ by the flutter web loader.
    return web.HTMLVideoElement()
      ..src = 'assets/$assetPath'
      ..controls = true
      ..preload = 'metadata'
      ..title = label
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'contain';
  });
  return HtmlElementView(viewType: viewType);
}

// coverage:ignore-end
