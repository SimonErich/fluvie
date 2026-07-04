import 'package:flutter/material.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/lessons/lesson.dart';

const _ink = Color(0xFF101020);
const _line = TextStyle(color: Colors.white, fontSize: 52);
const _badge = TextStyle(color: Color(0xFFF0B429), fontSize: 96, fontWeight: FontWeight.bold);

/// Lesson 02 — plain Flutter layout plus three motion ideas: a staggered
/// multi-child enter, a `previous` chain, and an ambient float.
const lesson02TextAndMotion = Lesson(
  id: '02_text_and_motion',
  title: 'Text and motion',
  intro:
      'A Column lays out three lines, one stagger animates them in turn, and '
      'a badge pops in and keeps floating. Scene defaults set the duration '
      'once for everything inside.',
  video: lesson02Video,
);

/// Builds the lesson 02 composition: a 5 second story-format canvas.
///
/// The scene's `motionDefaults` pin the duration to 18 frames, so no
/// animation below repeats it. The badge chains its float off the pop with
/// [Trigger.previous]; the column staggers its children 8 frames apart.
Video lesson02Video() {
  return Video(
    size: VideoSize.story,
    poster: 2.seconds,
    scenes: [
      // #docregion defaults
      Scene(
        duration: 5.seconds,
        motionDefaults: const Defaults(duration: Time.frames(18)),
        background: Background.color(_ink),
        children: [
          // #enddocregion defaults
          // #docregion column-stagger
          const Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 32,
            children: [
              Text('Layout is plain Flutter', style: _line),
              Text('Motion is one list', style: _line),
              Text('Timing happens for you', style: _line),
            ],
          ).animate([
            Animation.slideFade(stagger: const Stagger.each(Time.frames(8))),
          ]),
          // #enddocregion column-stagger
          // #docregion previous-chain
          Positioned(
            top: 360,
            child: const Text('02', style: _badge).animate([
              Animation.pop(),
              Animation.float(at: Trigger.previous, amplitude: 0.1),
            ]),
          ),
          // #enddocregion previous-chain
        ],
      ),
    ],
  );
}
