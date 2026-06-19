import 'package:flutter/material.dart' hide Animation, Image;
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/lessons/lesson.dart';

const _title = TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.bold);

/// The same bundled swatch, repeated to stand in for a data-driven photo set
/// (`for (final p in photos)`); offline, so the golden is stable.
const _photos = <String>[
  'assets/fixtures/swatch.png',
  'assets/fixtures/swatch.png',
  'assets/fixtures/swatch.png',
  'assets/fixtures/swatch.png',
  'assets/fixtures/swatch.png',
  'assets/fixtures/swatch.png',
];

/// Lesson 06 — a data-driven photo wall: a `Wrap` of framed
/// images staggers in over a gradient, then pixel post-effects finish the look.
const lesson06Collage = Lesson(
  id: '06_collage',
  title: 'A photo collage',
  intro:
      'A Wrap of framed photos staggers in over a gradient, six tiles two '
      'frames apart. Two pixel post-effects, grain and a vignette, sit in the '
      'same animate list and finish the frame after the transforms run, and a '
      'seeded confetti burst pops over the caption. One list of photos drives '
      'the whole wall, the way real data would.',
  video: lesson06Video,
);

/// Builds the lesson 06 composition: a 4 second square gallery at 30 fps.
///
/// The `Wrap` lays the photo tiles out left to right; one `slideFade` with a
/// per-child `Stagger` brings them in two frames apart. The same
/// list adds `grain` and `vignette`: pixel post-effects post-process the
/// already-laid-out wall, so list order between transforms and
/// pixels never matters. The caption fades up and a seeded `particles` confetti
/// burst rides over it, deterministic across every render.
Video lesson06Video() {
  return Video(
    size: VideoSize.square,
    poster: 2.seconds,
    scenes: [
      Scene(
        duration: 4.seconds,
        background: Background.gradient(const [Color(0xFF11998E), Color(0xFF38EF7D)]),
        children: [
          // #docregion pixel-fx
          Padding(
            padding: const EdgeInsets.fromLTRB(64, 64, 64, 180),
            child:
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  runAlignment: WrapAlignment.center,
                  children: [
                    for (final photo in _photos)
                      SizedBox(
                        width: 280,
                        height: 280,
                        child: Image.asset(photo, fit: BoxFit.cover, frame: const Frame.card()),
                      ),
                  ],
                ).animate([
                  // Transforms wrap the wall; the two pixel effects post-process
                  // the result, regardless of list order.
                  Animation.slideFade(stagger: const Stagger.each(Time.frames(2))),
                  Animation.grain(0.18),
                  Animation.vignette(0.4),
                ]),
          ),
          // #enddocregion pixel-fx
          Positioned(
            bottom: 96,
            child: const Text('Six moments', style: _title).animate([
              Animation.fadeIn(delay: 0.6.seconds),
              // A seeded confetti burst pops over the caption, identical on
              // every render.
              Animation.particles(const Particles.confetti(seed: 'six-moments')),
            ]),
          ),
        ],
      ),
    ],
  );
}
