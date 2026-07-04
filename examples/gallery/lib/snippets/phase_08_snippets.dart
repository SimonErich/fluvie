// Compiled, tested snippets for the text-and-typography,
// images-and-video-clips, and timeline-orchestration docs. They live here, not
// hand-typed in Markdown, so the documentation never drifts from a real API.
// Each `#docregion` flows into one fence via a `<!-- code-excerpt -->` marker.

// Timeline is @experimental by design; these snippets exist to
// document it, so the experimental-use warning is expected here.
// ignore_for_file: experimental_member_use
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';
import 'package:intl/intl.dart' show NumberFormat;

/// A title that fades and slides in — plain Flutter `Text` plus `.animate()`,
/// the whole of Fluvie's text story.
// #docregion text-animate
Widget animatedTitle() => const Text(
  'Made with Fluvie',
  style: TextStyle(fontSize: 64, fontWeight: FontWeight.bold),
).animate([Animation.slideFade(), Animation.fadeIn()]);
// #enddocregion text-animate

/// A frame-driven typewriter with a blinking caret.
// #docregion typewriter
Widget typedHeadline() => const Typewriter(
  'Typed out one glyph at a time.',
  speed: Time.frames(3),
  caret: true,
).animate([Animation.fadeIn()]);
// #enddocregion typewriter

/// A counter that tweens to a compact-formatted number.
// #docregion counter
Widget viewsCounter() =>
    Counter(to: 12500, reveal: 2.seconds, format: NumberFormat.compact()); // "12.5K"
// #enddocregion counter

/// The currency and percent presets, formatted at a fixed locale.
// #docregion counter-presets
Widget priceTag() => Counter.currency(to: 4999); // "$4,999"
Widget shareOfVoice() => Counter.percent(to: 0.87); // "87%"
// #enddocregion counter-presets

/// An opt-in timeline placing four animations on one shared clock.
/// `at:` takes a `Trigger`, a `String` label, or label arithmetic.
// #docregion timeline
Timeline introTimeline(Anchor title, Anchor subtitle, List<Anchor> bullets, Anchor cta) =>
    Timeline(defaults: const Defaults(duration: Time.seconds(0.5)))
      ..play(title, Animation.slideFade())
      ..play(subtitle, Animation.fadeIn(), at: Trigger.whenEnds(title))
      ..wait(0.3.seconds)
      ..playAll(bullets, Animation.slideFade(), stagger: 0.08.seconds)
      ..label('reveal')
      ..play(cta, Animation.pop(), at: 'reveal'.label - 0.2.seconds);
// #enddocregion timeline

/// A scene that adopts a timeline's derived length.
// #docregion scene-sequence
Scene sequencedScene(Timeline timeline) => Scene.sequence(
  timeline: timeline,
  background: Background.color(const Color(0xFF101820)),
  children: const [Text('Built on one clock')],
);
// #enddocregion scene-sequence

/// The four ways to name an image. Each source is pre-resolved
/// and cached by content hash before frame 0, so every frame is deterministic.
List<Image> imageConstructors(Uint8List bytes) => [
  // #docregion image-constructors
  Image.asset('photos/me.png'),
  Image.file('/tmp/frame.png'),
  Image.memory(bytes),
  Image.network('https://picsum.photos/seed/fluvie/800/800'),
  // #enddocregion image-constructors
];
