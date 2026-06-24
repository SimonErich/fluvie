import 'package:flutter/material.dart' hide Animation;
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/lessons/lesson.dart';

const _title = TextStyle(color: Colors.white, fontSize: 72, fontWeight: FontWeight.bold);
const _caption = TextStyle(color: Colors.white, fontSize: 40);

/// Lesson 03 — the quickstart shape: an anchored gradient shift, a title
/// gated on [Trigger.after], and a guest visible only inside a `.show`
/// window.
const lesson03TimingAndTriggers = Lesson(
  id: '03_timing_and_triggers',
  title: 'Timing and triggers',
  intro:
      'Name a timeline with an Anchor, react to it with Trigger.after, and '
      'bound an element with .show. Nobody computes a frame number.',
  video: lesson03Video,
);

/// Builds the lesson 03 composition: one 10 second square scene.
///
/// The gradient shifts from 1 s to 4 s (relative delay and duration), the
/// title slide-fades in exactly when the shift settles, and the caption
/// lives only in the middle of the scene, fading at both window edges.
Video lesson03Video() {
  final bg = Anchor('bg');
  return Video(
    size: VideoSize.square,
    poster: 6.seconds,
    scenes: [
      Scene(
        duration: 10.seconds,
        children: [
          // #docregion gradient-anchor
          Background.gradient(const [Color(0xFFE74C3C), Color(0xFF27AE60)]).animate([
            Animation.gradientShift(
              to: const [Color(0xFF2980B9), Color(0xFF27AE60)],
              duration: 0.3.relative, // 30% of the 10 s scene
              delay: 0.1.relative, // begins 1 s in
            ),
          ], anchor: bg),
          // #enddocregion gradient-anchor
          // #docregion after-trigger
          const Text('Hello, Fluvie', style: _title).animate([
            Animation.slideFade(at: Trigger.after(bg)),
          ]),
          // #enddocregion after-trigger
          // #docregion show-window
          Positioned(
            bottom: 200,
            child: const Text('Here from 5 s to 9 s', style: _caption)
                .show(from: 0.5.relative, to: 0.9.relative)
                .animate([Animation.fadeIn(), Animation.fadeOut()]),
          ),
          // #enddocregion show-window
        ],
      ),
    ],
  );
}
