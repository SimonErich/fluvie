import 'package:flutter/widgets.dart';

/// Off the web there is no HTML `video` element: show a flat, labeled
/// placeholder so the deck still presents (and goldens stay deterministic).
Widget buildVideoClipView(String assetPath, String label) => DecoratedBox(
  decoration: BoxDecoration(
    color: const Color(0xFF1B1B24),
    border: Border.all(color: const Color(0xFF3A3A46)),
  ),
  child: Center(
    child: Text(
      '$label\nplays in the web build',
      textAlign: TextAlign.center,
      style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 24, height: 1.6),
    ),
  ),
);
