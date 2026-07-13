import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';

Video _deck(List<Widget> children, {List<Widget> secondScene = const []}) => Video(
  width: 320,
  height: 180,
  scenes: [
    Scene(duration: const Time.seconds(2), children: children),
    if (secondScene.isNotEmpty) Scene(duration: const Time.seconds(2), children: secondScene),
  ],
);

List<List<SlideNotes>> _compile(Video video) => compileNotes(video, compileSlidePlans(video));

void main() {
  test('a scene note is the default for every step', () {
    final video = _deck([
      const SpeakerNotes(text: 'the story', highlights: ['one']),
      Stop.single(child: const SizedBox()),
    ]);
    final notes = _compile(video);
    expect(notes, hasLength(1));
    expect(notes[0], hasLength(2));
    expect(notes[0][0], const SlideNotes(text: 'the story', highlights: ['one']));
    expect(notes[0][1], const SlideNotes(text: 'the story', highlights: ['one']));
  });

  test('a per-step note overrides the text and augments the highlights', () {
    final video = _deck([
      const SpeakerNotes(text: 'scene default', highlights: ['always']),
      const Stop(
        children: [
          SizedBox(),
          SpeakerNotes(text: 'step one story', highlights: ['now']),
        ],
      ),
    ]);
    final notes = _compile(video);
    expect(notes[0][0], const SlideNotes(text: 'scene default', highlights: ['always']));
    expect(
      notes[0][1],
      const SlideNotes(text: 'step one story', highlights: ['always', 'now']),
    );
  });

  test('a step note without text keeps the scene text and adds bullets', () {
    final video = _deck([
      const SpeakerNotes(text: 'scene default'),
      const Stop(
        children: [
          SizedBox(),
          SpeakerNotes(highlights: ['reveal-only bullet']),
        ],
      ),
    ]);
    final notes = _compile(video);
    expect(
      notes[0][1],
      const SlideNotes(text: 'scene default', highlights: ['reveal-only bullet']),
    );
  });

  test('several notes in one scope merge in document order', () {
    final video = _deck([
      const SpeakerNotes(text: 'first paragraph', highlights: ['a']),
      const SizedBox(),
      const SpeakerNotes(text: 'second paragraph', highlights: ['b']),
    ]);
    final notes = _compile(video);
    expect(
      notes[0][0],
      const SlideNotes(text: 'first paragraph\n\nsecond paragraph', highlights: ['a', 'b']),
    );
  });

  test('a nested stop keeps its note on its own later step', () {
    const inner = Stop(
      children: [
        SizedBox(),
        SpeakerNotes(text: 'inner note'),
      ],
    );
    final video = _deck([
      const SpeakerNotes(text: 'scene'),
      const Stop(
        children: [
          SpeakerNotes(text: 'outer note'),
          inner,
        ],
      ),
    ]);
    final notes = _compile(video);
    // Steps: 0 = base, 1 = outer, 2 = inner (document order).
    expect(notes[0][0].text, 'scene');
    expect(notes[0][1].text, 'outer note');
    expect(notes[0][2].text, 'inner note');
  });

  test('a deck without notes compiles to empty notes', () {
    final video = _deck([const SizedBox()], secondScene: [const Text('x')]);
    final notes = _compile(video);
    expect(notes[0][0].isEmpty, isTrue);
    expect(notes[1][0].isEmpty, isTrue);
  });

  test('slides and steps line up with the compiled plans', () {
    final video = _deck(
      [const SpeakerNotes(text: 's0'), Stop.single(child: const SizedBox())],
      secondScene: [const SpeakerNotes(text: 's1')],
    );
    final plans = compileSlidePlans(video);
    final notes = compileNotes(video, plans);
    expect(notes, hasLength(plans.length));
    for (var s = 0; s < plans.length; s++) {
      expect(notes[s], hasLength(plans[s].stepCount));
    }
  });

  test('SlideNotes is a value', () {
    expect(
      const SlideNotes(text: 'a', highlights: ['x']),
      const SlideNotes(text: 'a', highlights: ['x']),
    );
    expect(
      const SlideNotes(text: 'a').hashCode,
      const SlideNotes(text: 'a').hashCode,
    );
    expect(const SlideNotes(text: 'a'), isNot(const SlideNotes(text: 'b')));
    expect(const SlideNotes(), isNot(const SlideNotes(highlights: ['x'])));
    expect(const SlideNotes().isEmpty, isTrue);
    expect(const SlideNotes(text: 'a').isEmpty, isFalse);
    expect(const SlideNotes(highlights: ['x']).isEmpty, isFalse);
    expect(const SlideNotes(text: 'a', highlights: ['x']).toString(), contains('a'));
  });
}
