import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart' show SlideNotes;

void main() {
  test('no notes anywhere merges to the empty view', () {
    expect(mergedSlideNotes(scene: null, step: null), const SlideNotes());
  });

  test('the scene default flows through untouched steps', () {
    final merged = mergedSlideNotes(
      scene: {
        'text': 'the story',
        'highlights': ['one'],
      },
      step: null,
    );
    expect(merged, const SlideNotes(text: 'the story', highlights: ['one']));
  });

  test('a step text replaces the scene text; highlights append', () {
    final merged = mergedSlideNotes(
      scene: {
        'text': 'scene default',
        'highlights': ['always'],
      },
      step: {
        'text': 'step one story',
        'highlights': ['now'],
      },
    );
    expect(merged, const SlideNotes(text: 'step one story', highlights: ['always', 'now']));
  });

  test('a text-less step override keeps the scene text and adds bullets', () {
    final merged = mergedSlideNotes(
      scene: {'text': 'scene default'},
      step: {
        'highlights': ['reveal-only bullet'],
      },
    );
    expect(merged, const SlideNotes(text: 'scene default', highlights: ['reveal-only bullet']));
  });

  test('malformed shapes read as absent — the panel stays up', () {
    final merged = mergedSlideNotes(
      scene: {'text': 7, 'highlights': 'nope'},
      step: {
        'highlights': [1, 'kept'],
      },
    );
    expect(merged, const SlideNotes(highlights: ['kept']));
  });
}
