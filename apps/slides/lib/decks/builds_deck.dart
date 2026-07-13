import 'package:flutter/widgets.dart' hide Animation;
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';

const _bg = Color(0xFF14141C);
const _ink = Color(0xFFF2F2F7);
const _dim = Color(0xFF8E8E93);
const _accent = Color(0xFF6C5CE7);
const _teal = Color(0xFF55EFC4);

Widget _bullet(String text, Color color) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 12),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(width: 16, height: 16, child: ColoredBox(color: color)),
      const SizedBox(width: 20),
      Text(text, style: const TextStyle(color: _ink, fontSize: 40)),
    ],
  ),
);

/// Lesson two: builds. Wrap anything in a `Stop` and it waits for a click,
/// then plays its authored entrance.
// #docregion builds-with-stop
Video buildsDeck() => Video(
  size: VideoSize.hd,
  scenes: [
    Scene(
      duration: const Time.seconds(8),
      background: Background.color(_bg),
      children: [
        Align(
          alignment: const Alignment(0, -0.6),
          child: const Text(
            'reveal on click',
            style: TextStyle(color: _ink, fontSize: 72),
          ).animate([Animation.fadeIn()]),
        ),
        Stop.single(
          child: Align(
            alignment: const Alignment(0, -0.1),
            child: _bullet(
              'each Stop is one step',
              _accent,
            ).animate([Animation.slideFadeIn(from: Edge.left)]),
          ),
        ),
        Stop.single(
          child: Align(
            alignment: const Alignment(0, 0.15),
            child: _bullet(
              'it plays its own entrance',
              _teal,
            ).animate([Animation.slideFadeIn(from: Edge.left)]),
          ),
        ),
        Stop.single(
          child: Align(
            alignment: const Alignment(0, 0.4),
            child: _bullet(
              'going back lands on the held state',
              _dim,
            ).animate([Animation.slideFadeIn(from: Edge.left)]),
          ),
        ),
      ],
    ),
    Scene(
      duration: const Time.seconds(6),
      background: Background.color(_bg),
      children: [
        const Text(
          'ambient motion never pauses',
          style: TextStyle(color: _ink, fontSize: 64),
        ).animate([Animation.fadeIn(), Animation.float()]),
        Stop.single(
          child: Align(
            alignment: const Alignment(0, 0.45),
            child: const Text(
              'even while a step holds',
              style: TextStyle(color: _dim, fontSize: 36),
            ).animate([Animation.pop()]),
          ),
        ),
      ],
    ),
  ],
);
// #enddocregion builds-with-stop
