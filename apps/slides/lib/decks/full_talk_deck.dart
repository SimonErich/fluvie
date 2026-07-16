import 'package:flutter/widgets.dart' hide Animation;
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';

const _bg = Color(0xFF14141C);
const _panel = Color(0xFF1B2838);
const _ink = Color(0xFFF2F2F7);
const _dim = Color(0xFF8E8E93);
const _accent = Color(0xFF6C5CE7);
const _teal = Color(0xFF55EFC4);

/// The end-to-end talk: builds, notes, transitions, ambient motion, a
/// chart, and code — most of the tool in one presentable deck.
// #docregion full-talk
Video fullTalkDeck() => Video(
  size: VideoSize.hd,
  transition: const Transition.crossFade(Time.seconds(0.4)),
  scenes: [
    Scene(
      duration: const Time.seconds(6),
      background: Background.color(_bg),
      children: [
        const SpeakerNotes(
          text: 'Say hello. One sentence on why slides are videos here.',
          highlights: ['hello', 'slides are videos'],
        ),
        const Text(
          'shipping the presenter',
          style: TextStyle(color: _ink, fontSize: 96),
        ).animate([Animation.fadeIn(duration: const Time.seconds(0.6)), Animation.float()]),
        Align(
          alignment: const Alignment(0, 0.35),
          child: const Text(
            'one Video, two audiences',
            style: TextStyle(color: _dim, fontSize: 40),
          ).animate([Animation.fadeIn(delay: const Time.seconds(0.4))]),
        ),
      ],
    ),
    Scene(
      duration: const Time.seconds(10),
      background: Background.color(_bg),
      children: [
        const SpeakerNotes(
          text: 'Walk the three claims slowly. Click between each.',
          highlights: ['same timing engine', 'steps are Stops', 'backs are instant'],
        ),
        Align(
          alignment: const Alignment(0, -0.65),
          child: const Text(
            'the pitch',
            style: TextStyle(color: _ink, fontSize: 64),
          ).animate([Animation.slideFadeIn()]),
        ),
        Stop.single(
          child: Align(
            alignment: const Alignment(-0.55, 0.05),
            child: _card('same timing engine', _accent),
          ),
        ),
        Stop.single(
          child: Align(
            alignment: const Alignment(0, 0.05),
            child: _card('steps are Stops', _teal),
          ),
        ),
        Stop(
          children: [
            const SpeakerNotes(text: 'Demo going back here: it lands, no rewind.'),
            Align(
              alignment: const Alignment(0.55, 0.05),
              child: _card('backs are instant', _dim),
            ),
          ],
        ),
      ],
    ),
    Scene(
      duration: const Time.seconds(8),
      background: Background.color(_bg),
      enter: const Transition.slide(Time.seconds(0.4)),
      children: [
        const SpeakerNotes(text: 'The adoption chart. Fridays are renders day.'),
        Align(
          alignment: const Alignment(0, -0.7),
          child: const Text(
            'it caught on',
            style: TextStyle(color: _ink, fontSize: 56),
          ).animate([Animation.fadeIn()]),
        ),
        Align(
          alignment: const Alignment(0, 0.35),
          child: SizedBox(
            width: 880,
            height: 400,
            child: Chart.bar(
              data: const {'w1': 3, 'w2': 9, 'w3': 17, 'w4': 30},
              reveal: const Time.seconds(0.5),
            ),
          ).animate([Animation.fadeIn()]),
        ),
      ],
    ),
    Scene(
      duration: const Time.seconds(6),
      background: Background.color(_bg),
      children: [
        const SpeakerNotes(
          text: 'Close on the one-liner and take questions.',
          highlights: ['questions'],
        ),
        const Text(
          'thanks — questions?',
          style: TextStyle(color: _ink, fontSize: 88),
        ).animate([Animation.pop()]),
      ],
    ),
  ],
);
// #enddocregion full-talk

Widget _card(String label, Color tint) => SizedBox(
  width: 380,
  height: 200,
  child: DecoratedBox(
    decoration: BoxDecoration(
      color: _panel,
      border: Border.all(color: tint, width: 3),
    ),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _ink, fontSize: 40),
        ),
      ),
    ),
  ),
).animate([Animation.slideFadeIn()]);
