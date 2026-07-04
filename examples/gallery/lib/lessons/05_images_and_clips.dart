// #docregion imports
// #docregion imports-flutter
import 'package:flutter/material.dart' hide Animation, Clip, Image, Tween;
// #enddocregion imports-flutter
// #docregion imports-fluvie
import 'package:fluvie/fluvie.dart'; // Image and Clip are Fluvie's here
// #enddocregion imports-fluvie
// #enddocregion imports
import 'package:fluvie_example/lessons/lesson.dart';

const _ink = Color(0xFF101820);
const _label = TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w600);

/// Lesson 05 — still images and embedded clips, pre-resolved so every frame is
/// deterministic: a framed photo that slowly zooms, and a trimmed video clip.
const lesson05ImagesAndClips = Lesson(
  id: '05_images_and_clips',
  title: 'Images and clips',
  intro:
      'A photo in a polaroid frame zooms with a Ken Burns move while a trimmed '
      'video clip plays beside it. Fluvie resolves every source before frame 0, '
      'so nothing pops in when it loads.',
  video: lesson05Video,
);

/// Builds the lesson 05 composition: a 3 second square scene at 30 fps with a
/// framed, zooming photo and a trimmed clip.
///
/// The photo is a bundled asset wrapped in a polaroid `Frame`; `kenBurns` gives
/// it a slow zoom. The clip plays the middle of `clip_1s.mp4` via `trim`. Both
/// sources are pre-resolved by the render harness, so the poster frame already
/// shows them with no async pop-in.
Video lesson05Video() {
  return Video(
    size: VideoSize.square,
    poster: 1.seconds,
    scenes: [
      Scene(
        duration: 3.seconds,
        background: Background.color(_ink),
        children: [
          Positioned(
            top: 120,
            child: const Text('Summer trip', style: _label).animate([Animation.fadeIn()]),
          ),
          // #docregion image-asset
          Align(
            alignment: const Alignment(0, -0.15),
            child: Image.asset(
              'assets/fixtures/swatch.png',
              fit: BoxFit.cover,
              frame: const Frame.polaroid(caption: 'Summer'),
            ).animate([Animation.kenBurns(zoom: 1.2)]),
          ),
          // #enddocregion image-asset
          // #docregion clip
          Align(
            alignment: const Alignment(0, 0.62),
            child: SizedBox(
              width: 360,
              height: 240,
              child: Clip.asset(
                'assets/fixtures/clip_1s.mp4',
                fit: BoxFit.cover,
                trim: 0.2.seconds.to(0.8.seconds),
              ).animate([Animation.fadeIn(delay: 0.3.seconds)]),
            ),
          ),
          // #enddocregion clip
        ],
      ),
    ],
  );
}

// A remote image resolves the same way: declare it, and Fluvie fetches,
// decodes, and caches it in the pre-resolve pass before any frame is drawn.
// #docregion image-network
Widget remotePhoto() => Image.network(
  'https://picsum.photos/seed/fluvie/800/800',
  fit: BoxFit.cover,
).animate([Animation.slideFade(), Animation.kenBurns(zoom: 1.2)]);
// #enddocregion image-network
