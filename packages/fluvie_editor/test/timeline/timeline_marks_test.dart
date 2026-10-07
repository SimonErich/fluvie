// The in and out marks, and which timeline bars are selected. Both are host
// state the commands read through a CommandScope, and neither is undoable:
// marking a range is aim, not an edit.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

ProviderContainer _container() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('the marks', () {
    test('start at nothing marked', () {
      final marks = _container().read(timelineMarksProvider);

      expect(marks.markIn, isNull);
      expect(marks.markOut, isNull);
      expect(marks.span, isNull);
    });

    test('take an in and an out', () {
      final container = _container();

      container.read(timelineMarksProvider.notifier).set(markIn: 10, markOut: 50);

      expect(container.read(timelineMarksProvider).span, (start: 10, end: 50));
    });

    test('a set with neither argument clears both', () {
      // The commands express "clear" as a call with nothing named, so the
      // absence of an argument has to mean absence, not "leave it alone".
      final container = _container();
      container.read(timelineMarksProvider.notifier).set(markIn: 10, markOut: 50);

      container.read(timelineMarksProvider.notifier).set();

      expect(container.read(timelineMarksProvider).markIn, isNull);
      expect(container.read(timelineMarksProvider).markOut, isNull);
    });

    test('an inverted pair is held but never reads as a span', () {
      // The scope decides which stale mark gives way; this state stores what
      // it is told and refuses to invent a range out of it.
      final container = _container();

      container.read(timelineMarksProvider.notifier).set(markIn: 50, markOut: 10);

      expect(container.read(timelineMarksProvider).span, isNull);
    });

    test('two states with the same marks are the same state', () {
      expect(
        const TimelineMarks(markIn: 1, markOut: 2),
        const TimelineMarks(markIn: 1, markOut: 2),
      );
      expect(
        const TimelineMarks(markIn: 1, markOut: 2).hashCode,
        const TimelineMarks(markIn: 1, markOut: 2).hashCode,
      );
      expect(const TimelineMarks(markIn: 1), isNot(const TimelineMarks(markIn: 2)));
    });
  });

  group('the timeline selection', () {
    test('starts empty', () {
      expect(_container().read(timelineSelectionProvider), isEmpty);
    });

    test('a plain click replaces it', () {
      final container = _container();
      container.read(timelineSelectionProvider.notifier)
        ..click('a')
        ..click('b');

      expect(container.read(timelineSelectionProvider), {'b'});
    });

    test('an additive click toggles one bar', () {
      final container = _container();
      container.read(timelineSelectionProvider.notifier)
        ..click('a')
        ..click('b', additive: true)
        ..click('a', additive: true);

      expect(container.read(timelineSelectionProvider), {'b'});
    });

    test('a click on nothing clears, unless it is additive', () {
      final container = _container();
      final selection = container.read(timelineSelectionProvider.notifier)
        ..click('a')
        ..click(null, additive: true);

      expect(container.read(timelineSelectionProvider), {'a'}, reason: 'a miss adds nothing');

      selection.click(null);
      expect(container.read(timelineSelectionProvider), isEmpty);
    });

    test('a marquee replaces or extends', () {
      final container = _container();
      final selection = container.read(timelineSelectionProvider.notifier)..marquee({'a', 'b'});

      expect(container.read(timelineSelectionProvider), {'a', 'b'});

      selection.marquee({'c'}, additive: true);
      expect(container.read(timelineSelectionProvider), {'a', 'b', 'c'});

      selection.marquee({'d'});
      expect(container.read(timelineSelectionProvider), {'d'});
    });

    test('pruning drops the bars a rebuild no longer draws', () {
      // Bars come and go as the document changes; a selection holding an id
      // nothing draws would let a verb act on a bar that is not there.
      final container = _container();

      container.read(timelineSelectionProvider.notifier)
        ..marquee({'a', 'b', 'c'})
        ..prune({'a', 'c'});

      expect(container.read(timelineSelectionProvider), {'a', 'c'});
    });
  });
}
