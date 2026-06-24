/// Templates `fluvie init` writes into a project.
///
/// These are plain source strings, kept separate from the command so each stays
/// reviewable. The starter composition mirrors
/// `examples/gallery/lib/starter/starter_video.dart` (the compiled source the docs
/// excerpt); `starter_template_test` asserts they stay in sync.
library;

/// The source of the starter composition file: a complete, runnable Fluvie
/// `Video` in real Flutter widget code.
///
/// [functionName] is the top-level builder name (a valid Dart identifier);
/// [key] is the render key shown in the header comment.
String starterCompositionSource({String functionName = 'starterVideo', String key = 'starter'}) =>
    '''
// A starter Fluvie video: one scene, a gradient background, an animated title.
//
// Preview it:  flutter run
// Render it:   fluvie render $key --out $key.mp4

import 'package:flutter/material.dart' hide Animation;
import 'package:fluvie/fluvie.dart';

/// Builds the starter composition: a 4 second square clip with a title that
/// fades and pops in. You describe what the video is; Fluvie decides when
/// everything happens.
Video $functionName() {
  return Video(
    size: VideoSize.square,
    poster: 1.seconds,
    scenes: [
      Scene(
        duration: 4.seconds,
        background: Background.gradient(const [Color(0xFF1A2980), Color(0xFF26D0CE)]),
        children: [
          const Text(
            'Hello, Fluvie',
            style: TextStyle(color: Colors.white, fontSize: 72, fontWeight: FontWeight.bold),
          ).animate([Animation.fadeIn(), Animation.pop()]),
        ],
      ),
    ],
  );
}
''';
