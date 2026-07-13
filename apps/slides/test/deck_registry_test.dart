import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';
import 'package:slides/deck/deck_registry.dart';

void main() {
  test('every bundled deck builds and compiles into presentable plans', () {
    for (final deck in bundledDecks) {
      final video = deck.build();
      expect(video.scenes, isNotEmpty, reason: deck.id);
      final plans = compileSlidePlans(video);
      expect(plans, hasLength(video.scenes.length), reason: deck.id);
      final notes = compileNotes(video, plans);
      expect(notes, hasLength(plans.length), reason: deck.id);
    }
  });

  test('the tutorial covers steps and notes', () {
    // The builds lesson has real steps; the notes lesson has real notes.
    final builds = compileSlidePlans(deckById('builds')!.build());
    expect(builds.first.stepCount, greaterThan(1));
    final notesDeck = deckById('notes')!.build();
    final notes = compileNotes(notesDeck, compileSlidePlans(notesDeck));
    expect(notes[0][0].isEmpty, isFalse);
    expect(notes[0][1].text, isNot(notes[0][0].text));
  });

  test('ids are unique and resolvable', () {
    final ids = bundledDecks.map((deck) => deck.id).toSet();
    expect(ids, hasLength(bundledDecks.length));
    expect(deckById('talk'), isNotNull);
    expect(deckById('nope'), isNull);
  });
}
