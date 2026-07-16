import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// The web player: one platform-view factory per asset (idempotent across
/// rebuilds), an HTML `video` with controls, sound, and autoplay. Chromium
/// allows sounding autoplay once the page has been interacted with (picking
/// the deck counts); Firefox blocks it until the site is allowed — the
/// controls are the fallback either way.
// coverage:ignore-start browser bindings need a real DOM
Widget buildVideoClipView(String assetPath, String label) {
  final viewType = 'slides-video-clip::$assetPath';
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
    // Bundled assets are served under assets/ by the flutter web loader.
    return web.HTMLVideoElement()
      ..src = 'assets/$assetPath'
      ..controls = true
      ..autoplay = true
      ..playsInline = true
      ..preload = 'auto'
      ..title = label
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'contain';
  });
  return HtmlElementView(viewType: viewType);
}

// coverage:ignore-end
