import 'package:flutter/widgets.dart' hide Animation;
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';

const _bg = Color(0xFF14141C);
const _ink = Color(0xFFF2F2F7);
const _dim = Color(0xFF8E8E93);
const _accent = Color(0xFF6C5CE7);
const _green = Color(0xFF2ECC8F);

/// Fourteen slides on what fluvie is and how it works. Every slide's
/// speaker notes describe exactly what is on screen, so the speaker window
/// can be checked against the stage slide by slide.
Video whatIsFluvieDeck() => Video(
  size: VideoSize.hd,
  scenes: [
    _title(),
    _theIdea(),
    _noTimeline(),
    _scenes(),
    _animations(),
    _triggers(),
    _elements(),
    _charts(),
    _code(),
    _media(),
    _audio(),
    _spec(),
    _presenter(),
    _closing(),
  ],
);

Scene _title() => Scene(
  duration: const Time.seconds(6),
  background: Background.color(_bg),
  children: [
    const SpeakerNotes(
      text:
          'Slide 1 of 14. Big white title "what is fluvie?" fades in over '
          'the dark background, with a grey subtitle "widgets in, video '
          'out" below it.',
      highlights: ['14 slides ahead', 'notes describe each slide'],
    ),
    const Text(
      'what is fluvie?',
      style: TextStyle(color: _ink, fontSize: 110),
    ).animate([Animation.fadeIn(duration: const Time.seconds(0.6))]),
    Align(
      alignment: const Alignment(0, 0.35),
      child: const Text(
        'widgets in, video out',
        style: TextStyle(color: _dim, fontSize: 44),
      ).animate([Animation.fadeIn(delay: const Time.seconds(0.4))]),
    ),
  ],
);

Scene _theIdea() => Scene(
  duration: const Time.seconds(6),
  background: Background.color(_bg),
  children: [
    const SpeakerNotes(
      text:
          'Slide 2. Headline "you write widgets" with a second line '
          '"fluvie shoots the film" sliding in underneath. No other '
          'visuals.',
      highlights: ['Flutter widgets are the source', 'the output is a real MP4'],
    ),
    Align(
      alignment: const Alignment(0, -0.2),
      child: const Text(
        'you write widgets',
        style: TextStyle(color: _ink, fontSize: 84),
      ).animate([Animation.fadeIn()]),
    ),
    Align(
      alignment: const Alignment(0, 0.2),
      child: const Text(
        'fluvie shoots the film',
        style: TextStyle(color: _accent, fontSize: 60),
      ).animate([Animation.slideFadeIn(delay: const Time.seconds(0.5))]),
    ),
  ],
);

Scene _noTimeline() => Scene(
  duration: const Time.seconds(6),
  background: Background.color(_bg),
  children: [
    const SpeakerNotes(
      text:
          'Slide 3. One statement centered: "no timeline to scrub", and a '
          'grey line explaining you declare durations and fluvie computes '
          'when everything happens.',
      highlights: ['declarative timing', 'no keyframe dragging'],
    ),
    Align(
      alignment: const Alignment(0, -0.15),
      child: const Text(
        'no timeline to scrub',
        style: TextStyle(color: _ink, fontSize: 80),
      ).animate([Animation.fadeIn()]),
    ),
    Align(
      alignment: const Alignment(0, 0.22),
      child: const Text(
        'you say how long things last; fluvie computes when they happen',
        style: TextStyle(color: _dim, fontSize: 38),
      ).animate([Animation.fadeIn(delay: const Time.seconds(0.4))]),
    ),
  ],
);

Scene _scenes() => Scene(
  duration: const Time.seconds(8),
  background: Background.color(_bg),
  children: [
    const SpeakerNotes(
      text:
          'Slide 4. Title "a Video is a list of Scenes" with three purple '
          'blocks labeled scene 1, 2, 3 in a row. The blocks appear one per '
          'click.',
      highlights: ['each block reveals on advance', 'three clicks, three scenes'],
    ),
    Align(
      alignment: const Alignment(0, -0.6),
      child: const Text(
        'a Video is a list of Scenes',
        style: TextStyle(color: _ink, fontSize: 64),
      ).animate([Animation.fadeIn()]),
    ),
    for (var i = 0; i < 3; i++)
      Stop.single(
        child: Align(
          alignment: Alignment(-0.5 + i * 0.5, 0.2),
          child: SizedBox(
            width: 360,
            height: 220,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.25),
                border: Border.all(color: _accent, width: 2),
              ),
              child: Center(
                child: Text(
                  'scene ${i + 1}',
                  style: const TextStyle(color: _ink, fontSize: 40),
                ),
              ),
            ),
          ).animate([Animation.slideFadeIn(duration: const Time.seconds(0.4))]),
        ),
      ),
  ],
);

Scene _animations() => Scene(
  duration: const Time.seconds(7),
  background: Background.color(_bg),
  children: [
    const SpeakerNotes(
      text:
          'Slide 5. Title "animations are presets". Three words demo '
          'themselves: "fade" fades in, "slide" slides in from the bottom, '
          '"pop" pops — left to right, slightly staggered.',
      highlights: ['each word demos its preset', 'floating never stops'],
    ),
    Align(
      alignment: const Alignment(0, -0.55),
      child: const Text(
        'animations are presets',
        style: TextStyle(color: _ink, fontSize: 64),
      ).animate([Animation.fadeIn()]),
    ),
    Align(
      alignment: const Alignment(-0.5, 0.15),
      child: const Text(
        'fade',
        style: TextStyle(color: _dim, fontSize: 56),
      ).animate([Animation.fadeIn(duration: const Time.seconds(1))]),
    ),
    Align(
      alignment: const Alignment(0, 0.15),
      child: const Text(
        'slide',
        style: TextStyle(color: _accent, fontSize: 56),
      ).animate([Animation.slideFadeIn(delay: const Time.seconds(0.6))]),
    ),
    Align(
      alignment: const Alignment(0.5, 0.15),
      child: const Text(
        'pop',
        style: TextStyle(color: _green, fontSize: 56),
      ).animate([Animation.pop(delay: const Time.seconds(1.2))]),
    ),
  ],
);

Scene _triggers() => Scene(
  duration: const Time.seconds(6),
  background: Background.color(_bg),
  children: [
    const SpeakerNotes(
      text:
          'Slide 6. Title "things can wait for each other" and a grey '
          'sentence about triggers: an animation can start when another '
          'element finishes, or on an audio beat.',
      highlights: ['triggers chain animations', 'beats can drive motion'],
    ),
    Align(
      alignment: const Alignment(0, -0.15),
      child: const Text(
        'things can wait for each other',
        style: TextStyle(color: _ink, fontSize: 68),
      ).animate([Animation.fadeIn()]),
    ),
    Align(
      alignment: const Alignment(0, 0.22),
      child: const Text(
        'start after another element, at a moment, or on a beat',
        style: TextStyle(color: _dim, fontSize: 38),
      ).animate([Animation.fadeIn(delay: const Time.seconds(0.4))]),
    ),
  ],
);

Scene _elements() => Scene(
  duration: const Time.seconds(6),
  background: Background.color(_bg),
  children: [
    const SpeakerNotes(
      text:
          'Slide 7. Title "batteries included" over a typewriter line that '
          'types out the element names: text, images, clips, charts, code, '
          'counters.',
      highlights: ['the typewriter is typing live', 'all plain fluvie elements'],
    ),
    Align(
      alignment: const Alignment(0, -0.3),
      child: const Text(
        'batteries included',
        style: TextStyle(color: _ink, fontSize: 72),
      ).animate([Animation.fadeIn()]),
    ),
    const Align(
      alignment: Alignment(0, 0.15),
      child: Typewriter(
        'text. images. clips. charts. code. counters.',
        style: TextStyle(color: _dim, fontSize: 44),
      ),
    ),
  ],
);

Scene _charts() => Scene(
  duration: const Time.seconds(8),
  background: Background.color(_bg),
  children: [
    const SpeakerNotes(
      text:
          'Slide 8. A bar chart grows in the middle under the title "data '
          'animates itself": five bars labeled mon to fri, the tallest on '
          'friday.',
      highlights: ['bars grow on entry', 'friday is the tallest'],
    ),
    Align(
      alignment: const Alignment(0, -0.7),
      child: const Text(
        'data animates itself',
        style: TextStyle(color: _ink, fontSize: 56),
      ).animate([Animation.fadeIn()]),
    ),
    Align(
      alignment: const Alignment(0, 0.3),
      child: SizedBox(
        width: 900,
        height: 420,
        // Absolute reveal: relative times resolve against the presenter's
        // stretched scene, so decks spell durations out.
        child: Chart.bar(
          data: const {'mon': 12, 'tue': 18, 'wed': 32, 'thu': 26, 'fri': 41},
          reveal: const Time.seconds(0.5),
        ),
      ).animate([Animation.fadeIn(duration: const Time.seconds(0.5))]),
    ),
  ],
);

Scene _code() => Scene(
  duration: const Time.seconds(7),
  background: Background.color(_bg),
  children: [
    const SpeakerNotes(
      text:
          'Slide 9. Title "a whole video, one function" above a dark code '
          'block showing a Video with one Scene and a fadeIn text — real '
          'highlighted Dart.',
      highlights: ['this code is the product', 'compare it with slide 4'],
    ),
    Align(
      alignment: const Alignment(0, -0.75),
      child: const Text(
        'a whole video, one function',
        style: TextStyle(color: _ink, fontSize: 52),
      ).animate([Animation.fadeIn()]),
    ),
    Align(
      alignment: const Alignment(0, 0.25),
      child: SizedBox(
        width: 1040,
        child: const Code('''
Video(
  scenes: [
    Scene(
      duration: Time.seconds(3),
      children: [
        Text('hello').animate([Animation.fadeIn()]),
      ],
    ),
  ],
)
''', language: 'dart').animate([Animation.slideFadeIn()]),
      ),
    ),
  ],
);

Scene _media() => Scene(
  duration: const Time.seconds(6),
  background: Background.color(_bg),
  children: [
    const SpeakerNotes(
      text:
          'Slide 10. Title "media is pre-resolved" with a grey explainer: '
          'images and clips download and decode before the frame loop, '
          'cached by content hash.',
      highlights: ['no mid-frame loading', 'cache keyed by content'],
    ),
    Align(
      alignment: const Alignment(0, -0.15),
      child: const Text(
        'media is pre-resolved',
        style: TextStyle(color: _ink, fontSize: 72),
      ).animate([Animation.fadeIn()]),
    ),
    Align(
      alignment: const Alignment(0, 0.22),
      child: const Text(
        'images and clips are fetched and decoded before a single frame renders',
        style: TextStyle(color: _dim, fontSize: 36),
      ).animate([Animation.fadeIn(delay: const Time.seconds(0.4))]),
    ),
  ],
);

Scene _audio() => Scene(
  duration: const Time.seconds(6),
  background: Background.color(_bg),
  children: [
    const SpeakerNotes(
      text:
          'Slide 11. Title "sound is a mix, not a race" with the explainer '
          'that audio tracks are combined by FFmpeg at render time — '
          'volumes, fades, and beats included.',
      highlights: ['audio mixes at render time', 'beats can drive visuals'],
    ),
    Align(
      alignment: const Alignment(0, -0.15),
      child: const Text(
        'sound is a mix, not a race',
        style: TextStyle(color: _ink, fontSize: 70),
      ).animate([Animation.fadeIn()]),
    ),
    Align(
      alignment: const Alignment(0, 0.22),
      child: const Text(
        'tracks, volumes, and fades combine in the encoder',
        style: TextStyle(color: _dim, fontSize: 38),
      ).animate([Animation.fadeIn(delay: const Time.seconds(0.4))]),
    ),
  ],
);

Scene _spec() => Scene(
  duration: const Time.seconds(7),
  background: Background.color(_bg),
  children: [
    const SpeakerNotes(
      text:
          'Slide 12. Title "or write it as JSON" over a code block with a '
          'tiny .fluvie document — the same deck format this app opens '
          'from disk.',
      highlights: ['.fluvie files are VideoSpec JSON', 'tools can generate them'],
    ),
    Align(
      alignment: const Alignment(0, -0.75),
      child: const Text(
        'or write it as JSON',
        style: TextStyle(color: _ink, fontSize: 56),
      ).animate([Animation.fadeIn()]),
    ),
    Align(
      alignment: const Alignment(0, 0.2),
      child: SizedBox(
        width: 1040,
        child: const Code('''
{
  "fluvieSpec": 1,
  "scenes": [
    {"duration": "3s", "children": [{"type": "Text", "text": "hello"}]}
  ]
}
''', language: 'json').animate([Animation.slideFadeIn()]),
      ),
    ),
  ],
);

Scene _presenter() => Scene(
  duration: const Time.seconds(8),
  background: Background.color(_bg),
  children: [
    const SpeakerNotes(
      text:
          'Slide 13. Title "and it presents itself". Two green statements '
          'reveal on advance: "this deck is a fluvie Video" and "the same '
          'file renders as a film".',
      highlights: ['you are watching the proof', 'two reveals on this slide'],
    ),
    Align(
      alignment: const Alignment(0, -0.5),
      child: const Text(
        'and it presents itself',
        style: TextStyle(color: _ink, fontSize: 72),
      ).animate([Animation.fadeIn()]),
    ),
    Stop.single(
      child: Align(
        alignment: const Alignment(0, 0.05),
        child: const Text(
          'this deck is a fluvie Video',
          style: TextStyle(color: _green, fontSize: 48),
        ).animate([Animation.slideFadeIn(duration: const Time.seconds(0.4))]),
      ),
    ),
    Stop.single(
      child: Align(
        alignment: const Alignment(0, 0.35),
        child: const Text(
          'the same file renders as a film',
          style: TextStyle(color: _green, fontSize: 48),
        ).animate([Animation.slideFadeIn(duration: const Time.seconds(0.4))]),
      ),
    ),
  ],
);

Scene _closing() => Scene(
  duration: const Time.seconds(6),
  background: Background.color(_bg),
  children: [
    const SpeakerNotes(
      text:
          'Slide 14, the last one. "write widgets, ship films" in white '
          'over a purple underline bar, with the docs pointer in grey at '
          'the bottom.',
      highlights: ['closing slide', 'point at the documentation'],
    ),
    const Text(
      'write widgets, ship films',
      style: TextStyle(color: _ink, fontSize: 84),
    ).animate([Animation.fadeIn()]),
    Align(
      alignment: const Alignment(0, 0.25),
      child: const Box(
        color: _accent,
        size: Size(0.35, 0.015),
      ).animate([Animation.slideFadeIn(delay: const Time.seconds(0.4))]),
    ),
    Align(
      alignment: const Alignment(0, 0.6),
      child: const Text(
        'docs live in the fluvie repo; this deck is lib/decks/what_is_fluvie_deck.dart',
        style: TextStyle(color: _dim, fontSize: 32),
      ).animate([Animation.fadeIn(delay: const Time.seconds(0.6))]),
    ),
  ],
);
