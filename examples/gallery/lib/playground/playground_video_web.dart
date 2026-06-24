import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:fluvie_example/theme/fluvie_colors.dart';
import 'package:web/web.dart' as web;

/// The web Playground video area: an HTML `<video controls>` for the rendered
/// [url], or an empty-state prompt before the first render.
///
/// Registers one platform-view factory per URL (idempotent across rebuilds) and
/// shows it through [HtmlElementView]. Only compiled on web, so the `dart:ui_web`
/// and `package:web` imports never reach the VM build.
// coverage:ignore-start
final class PlaygroundVideo extends StatelessWidget {
  /// Creates the video area for the rendered [url], or the empty state when
  /// [url] is null.
  const PlaygroundVideo({required this.url, super.key});

  /// Where the rendered video can be downloaded and played, or null.
  final String? url;

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    if (url == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.movie_outlined, size: 40, color: FluvieColors.acc2),
            SizedBox(height: 12),
            Text('Render to see your video', style: TextStyle(color: FluvieColors.dtext)),
          ],
        ),
      );
    }
    final viewType = 'fluvie-playground-video::$url';
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      return web.HTMLVideoElement()
        ..src = url
        ..controls = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'contain';
    });
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: HtmlElementView(viewType: viewType),
    );
  }
}

// coverage:ignore-end
