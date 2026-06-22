import 'package:flutter/material.dart';

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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: url == null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.movie_outlined, size: 40, color: scheme.onSurfaceVariant),
                const SizedBox(height: 12),
                const Text('Render to see your video'),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline, size: 40, color: scheme.primary),
                const SizedBox(height: 12),
                const Text('Your video is ready'),
                const SizedBox(height: 8),
                SelectableText(url, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
    );
  }
}
