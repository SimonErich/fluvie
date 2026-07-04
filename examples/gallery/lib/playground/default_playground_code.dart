/// The snippet the Playground editor opens with: a complete, valid Fluvie
/// `Video build()` that renders a fading, popping title over a gradient.
///
/// It mirrors lesson 01 so the first render always succeeds, giving newcomers a
/// known-good starting point to edit.
const defaultPlaygroundCode = '''
import 'package:flutter/material.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';

Video build() {
  return Video(
    size: VideoSize.square,
    scenes: [
      Scene(
        duration: 4.seconds,
        background: Background.gradient(const [Color(0xFF1A2980), Color(0xFF26D0CE)]),
        children: [
          const Text(
            'Hello, Fluvie',
            style: TextStyle(
              color: Colors.white,
              fontSize: 72,
              fontWeight: FontWeight.bold,
            ),
          ).animate([Animation.fadeIn(), Animation.pop()]),
        ],
      ),
    ],
  );
}
''';
