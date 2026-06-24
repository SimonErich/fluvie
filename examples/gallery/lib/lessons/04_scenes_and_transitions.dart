import 'package:flutter/material.dart' hide Animation;
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/lessons/lesson.dart';

const _ink = Color(0xFF0B1021);
const _brand = Color(0xFFF0B429);
const _title = TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.bold);
const _stat = TextStyle(color: _brand, fontSize: 120, fontWeight: FontWeight.bold);
const _caption = TextStyle(color: Colors.white70, fontSize: 36);
const _outro = TextStyle(color: Colors.white, fontSize: 52);

/// Lesson 04 — three scenes, three boundary behaviours: an overlapping
/// `crossFade` default, a `SharedElement` logo that morphs across it, a
/// `Camera.push` on the middle scene, and a sequential `wipe` into the last.
const lesson04ScenesAndTransitions = Lesson(
  id: '04_scenes_and_transitions',
  title: 'Scenes and transitions',
  intro:
      'A video default crossFade overlaps the first two scenes, a shared logo '
      'morphs across that boundary, the stats scene pushes its camera, and a '
      'wipe carries you into the outro. You never compute a frame number.',
  video: lesson04Video,
);

/// Builds the lesson 04 composition: three 3 second square scenes at 30 fps.
///
/// The video default `crossFade` overlaps the first boundary, so the total
/// shortens by its 15 frames; the `SharedElement` pair morphs the brand block
/// from centre-large to corner-small across that boundary; scene 2 pushes its
/// camera in; scene 3's `enter` wipe runs sequentially (`overlap: false`), so
/// it leaves the total length alone. `poster` sits inside the first blend
/// window so the thumbnail shows the crossFade itself.
Video lesson04Video() {
  // #docregion shared-anchor
  final logo = Anchor('logo');
  // #enddocregion shared-anchor
  return Video(
    size: VideoSize.square,
    poster: const Time.frames(82),
    // #docregion video-default
    transition: Transition.crossFade(0.5.seconds), // overlap is on by default
    // #enddocregion video-default
    scenes: [
      // #docregion title-scene
      Scene(
        duration: 3.seconds,
        background: Background.gradient(const [Color(0xFF1D2671), Color(0xFFC33764)]),
        children: [
          SharedElement(
            anchor: logo,
            child: const Box(color: _brand, size: Size(0.4, 0.4)),
          ),
          const Text('Year in review', style: _title).animate([
            Animation.slideFade(at: Trigger.sceneEnd),
          ]),
        ],
      ),
      // #enddocregion title-scene
      // #docregion camera-scene
      Scene(
        duration: 3.seconds,
        background: Background.color(_ink),
        camera: const Camera.push(zoom: 1.25),
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: SharedElement(
              anchor: logo,
              child: const Box(color: _brand, size: Size(0.12, 0.12)),
            ),
          ),
          const Center(child: Text('48,230', style: _stat)),
          Positioned(
            bottom: 220,
            child: const Text('minutes listened', style: _caption).animate([
              Animation.fadeIn(delay: 1.seconds),
            ]),
          ),
        ],
      ),
      // #enddocregion camera-scene
      // #docregion wipe-scene
      Scene.centered(
        duration: 3.seconds,
        background: Background.color(_ink),
        enter: Transition.wipe(0.4.seconds, overlap: false),
        child: const Text('See you next year', style: _outro).animate([
          Animation.blurIn(),
          Animation.fadeOut(),
        ]),
      ),
      // #enddocregion wipe-scene
    ],
  );
}
