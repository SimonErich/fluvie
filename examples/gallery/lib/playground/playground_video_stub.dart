import 'package:flutter/material.dart';
import 'package:fluvie_example/theme/fluvie_colors.dart';

/// The non-web Playground video area (VM, mobile, tests).
///
/// With no [url] it shows an empty-state prompt; with one it shows a card
/// confirming the render is ready (the real `<video>` element only exists on
/// web). This file never imports `dart:ui_web` or `package:web`.
final class PlaygroundVideo extends StatelessWidget {
  /// Creates the video area for the rendered [url], or the empty state when
  /// [url] is null.
  const PlaygroundVideo({required this.url, super.key});

  /// Where the rendered video can be downloaded, or null before a render.
  final String? url;

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    return Center(
      child: url == null
          ? const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.movie_outlined, size: 40, color: FluvieColors.acc2),
                SizedBox(height: 12),
                Text('Render to see your video', style: TextStyle(color: FluvieColors.dtext)),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline, size: 40, color: FluvieColors.dotGreen),
                const SizedBox(height: 12),
                const Text('Your video is ready', style: TextStyle(color: FluvieColors.dtext)),
                const SizedBox(height: 8),
                SelectableText(url, style: const TextStyle(color: FluvieColors.dmut, fontSize: 12)),
              ],
            ),
    );
  }
}
