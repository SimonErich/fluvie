// #docregion imports
import 'package:flutter/material.dart' hide Animation;
import 'package:fluvie/fluvie.dart';
// #enddocregion imports
import 'package:fluvie_example/lessons/lesson.dart';

/// Lesson 01 — the smallest complete Fluvie video: one square scene, a
/// gradient backdrop, and a title that fades and pops into place.
const lesson01HelloVideo = Lesson(
  id: '01_hello_video',
  title: 'Hello, video',
  intro:
      'One scene, one background, one animated title. You describe what the '
      'video is; Fluvie decides when everything happens.',
  video: lesson01Video,
);

/// Builds the lesson 01 composition: a 4 second square canvas at the
/// default 30 fps.
///
/// The title carries two enter animations in one `.animate([...])` list, a
/// fade and a springy pop, and both start together at the scene start.
/// `poster: 1.seconds` marks the frame the gallery and the goldens show.
// #docregion video
Video lesson01Video() {
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
