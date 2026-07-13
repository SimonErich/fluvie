import 'package:flutter/widgets.dart' hide Animation;
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';

const _bg = Color(0xFF14141C);
const _ink = Color(0xFFF2F2F7);
const _dim = Color(0xFF8E8E93);

/// Lesson four: a media-heavy slide. Charts, code, and typewriter text are
/// plain fluvie elements — the presenter plays them like everything else.
// #docregion media-slide
Video mediaDeck() => Video(
  size: VideoSize.hd,
  scenes: [
    Scene(
      duration: const Time.seconds(8),
      background: Background.color(_bg),
      children: [
        Align(
          alignment: const Alignment(0, -0.7),
          child: const Text(
            'renders per weekday',
            style: TextStyle(color: _ink, fontSize: 56),
          ).animate([Animation.fadeIn()]),
        ),
        Align(
          alignment: const Alignment(0, 0.3),
          child: SizedBox(
            width: 900,
            height: 420,
            // An absolute reveal: relative times resolve against the
            // presenter's stretched scene, so decks spell durations out.
            child: Chart.bar(
              data: const {'mon': 12, 'tue': 18, 'wed': 32, 'thu': 26, 'fri': 41},
              reveal: const Time.seconds(0.5),
            ),
          ).animate([Animation.fadeIn(duration: const Time.seconds(0.5))]),
        ),
      ],
    ),
    Scene(
      duration: const Time.seconds(8),
      background: Background.color(_bg),
      children: [
        Align(
          alignment: const Alignment(0, -0.75),
          child: const Text(
            'and this is all it takes',
            style: TextStyle(color: _dim, fontSize: 44),
          ).animate([Animation.fadeIn()]),
        ),
        Stop.single(
          child: Align(
            alignment: const Alignment(0, 0.2),
            child: SizedBox(
              width: 920,
              child: const Code('''
runApp(FluvieSlides(video));
''', language: 'dart').animate([Animation.slideFadeIn()]),
            ),
          ),
        ),
      ],
    ),
    Scene(
      duration: const Time.seconds(6),
      background: Background.color(_bg),
      children: const [
        Typewriter('live elements welcome.', style: TextStyle(color: _ink, fontSize: 64)),
      ],
    ),
  ],
);
// #enddocregion media-slide
