// The starter composition `fluvie init` scaffolds, kept here as the compiled,
// analyzed source of truth that the docs excerpt and the CLI template mirrors.
// The fluvie_cli `starter_template_sync_test` asserts the CLI template stays in
// sync with the regions below.
//
// It declares `build`, not a named builder: that is the entry point convention
// `fluvie render` and `fluvie preview` look for in a composition file.

// #docregion imports
import 'package:flutter/material.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';
// #enddocregion imports

// #docregion video
/// Builds the starter composition: a 4 second square clip with a title that
/// fades and pops in. You describe what the video is; Fluvie decides when
/// everything happens.
Video build() {
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

// #enddocregion video
