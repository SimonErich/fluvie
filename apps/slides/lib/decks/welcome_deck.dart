import 'package:flutter/widgets.dart' hide Animation;
import 'package:fluvie/fluvie.dart';

const _bg = Color(0xFF14141C);
const _ink = Color(0xFFF2F2F7);
const _dim = Color(0xFF8E8E93);
const _accent = Color(0xFF6C5CE7);

/// Lesson one: plain slides. One scene is one slide; nothing else to learn.
// #docregion plain-slides
Video welcomeDeck() => Video(
  size: VideoSize.hd,
  scenes: [
    Scene(
      duration: const Time.seconds(6),
      background: Background.color(_bg),
      children: [
        const Text(
          'fluvie slides',
          style: TextStyle(color: _ink, fontSize: 120),
        ).animate([Animation.fadeIn(duration: const Time.seconds(0.6)), Animation.float()]),
        Align(
          alignment: const Alignment(0, 0.35),
          child: const Text(
            'a Video, presented live',
            style: TextStyle(color: _dim, fontSize: 44),
          ).animate([Animation.fadeIn(delay: const Time.seconds(0.4))]),
        ),
      ],
    ),
    Scene(
      duration: const Time.seconds(6),
      background: Background.color(_bg),
      children: [
        const Text(
          'every scene is a slide',
          style: TextStyle(color: _ink, fontSize: 72),
        ).animate([Animation.slideFadeIn()]),
        Align(
          alignment: const Alignment(0, 0.4),
          child: const Text(
            'arrows, space, or a remote to move — F for fullscreen',
            style: TextStyle(color: _dim, fontSize: 36),
          ).animate([Animation.fadeIn(delay: const Time.seconds(0.5))]),
        ),
      ],
    ),
    Scene(
      duration: const Time.seconds(6),
      background: Background.color(_bg),
      children: [
        Align(
          alignment: const Alignment(0, -0.5),
          child: const Text(
            'and the same file still renders as a video',
            style: TextStyle(color: _ink, fontSize: 56),
          ).animate([Animation.fadeIn()]),
        ),
        const Box(
          color: _accent,
          size: Size(0.4, 0.08),
        ).animate([Animation.slideFadeIn(delay: const Time.seconds(0.4))]),
      ],
    ),
  ],
);
// #enddocregion plain-slides
