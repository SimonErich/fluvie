// Compiled source for authoring documentation and the public website.
// ignore_for_file: experimental_member_use
// #docregion asset-story
import 'package:flutter/material.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';

/// A small story using files in the project's assets folder.
Video build() => Video(
  size: VideoSize.hd,
  poster: 1.seconds,
  audio: const [Audio.music('assets/music/song.mp3', volume: 0.3)],
  scenes: [
    Scene(
      duration: 4.seconds,
      children: [
        Clip.asset('assets/cat/playing.mp4', fit: BoxFit.cover, audio: const ClipAudio.muted()),
        const Align(
          alignment: Alignment.bottomCenter,
          child: Text('A day in the life of my cat', style: TextStyle(fontSize: 64)),
        ).animate([Animation.fadeIn()]),
      ],
    ),
  ],
);
// #enddocregion asset-story

// #docregion website-promo
/// A real Flutter composition: the same source is displayed on the website.
Video promo() => Video(
  size: const VideoSize(320, 320),
  fps: 12,
  poster: 3.seconds,
  scenes: [
    Scene.centered(
      duration: 10.seconds,
      background: Background.color(const Color(0xFF0E9E8E)),
      child: Counter(
        to: 10000,
        reveal: 3.seconds,
        style: const TextStyle(fontSize: 48, color: Colors.white),
      ),
    ),
  ],
);
// #enddocregion website-promo

// #docregion website-start
Video startExample() => Video(
  size: VideoSize.square,
  scenes: [
    Scene.centered(
      duration: 4.seconds,
      background: Background.color(const Color(0xFF0E9E8E)),
      child: const Text(
        'Hello, Fluvie',
        style: TextStyle(fontSize: 64, color: Colors.white),
      ).animate([Animation.fadeIn(), Animation.pop()]),
    ),
  ],
);
// #enddocregion website-start

// #docregion video-preview
/// Embeds the authored composition in your own Flutter app.
Widget preview() => const VideoPreview.builder(builder: build);
// #enddocregion video-preview

// #docregion clip-transition
/// Blend two adjacent clips without serializing the composition.
Scene twoClips(String outgoingAsset, String incomingAsset) => Scene(
  duration: 4.seconds,
  children: [
    ClipTransitionGroup(
      transitions: [
        ClipTransition(
          outgoing: 'playing',
          incoming: 'resting',
          transition: Transition.crossFade(10.frames),
        ),
      ],
      children: [
        ElementId(
          id: 'playing',
          lane: 'cat',
          child: Clip.asset(outgoingAsset).show(from: 0.frames, to: 60.frames),
        ),
        ElementId(
          id: 'resting',
          lane: 'cat',
          child: Clip.asset(incomingAsset).show(from: 60.frames, to: 120.frames),
        ),
      ],
    ),
  ],
);
// #enddocregion clip-transition

// #docregion scale-clip-audio
/// Change a clip's gain without discarding its original fade policy.
ClipAudio quietClip() => ClipAudio.included(
  volume: 0.8,
  fadeIn: 0.2.seconds,
  fadeOut: 0.3.seconds,
).scaledBy(0.5);
// #enddocregion scale-clip-audio

// #docregion dynamic-resources
/// Prepare an image whose widget first appears on a later video frame.
Widget laterPhoto() => FrameBuilder(
  (ctx) => ctx.frame < 60 ? const SizedBox.shrink() : Image.asset('assets/cat/later.png'),
  resources: const CompositionResources(media: [MediaSource.asset('assets/cat/later.png')]),
);
// #enddocregion dynamic-resources
