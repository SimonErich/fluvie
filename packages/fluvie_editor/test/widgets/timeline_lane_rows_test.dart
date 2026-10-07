// The timeline's row geometry. Every surface that asks "which lane is under
// this pixel" asks here, so the labels, the painter and the hit test can
// never disagree about where a row starts.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

List<TimelineTrack> _tracks() => const [
  TimelineTrack(id: 'a', label: 'A'),
  TimelineTrack(id: 'b', label: 'B', height: 60),
  TimelineTrack(id: 'c', label: 'C'),
];

TimelineLaneRows _rows({List<TimelineTrack>? tracks}) =>
    TimelineLaneRows(tracks: tracks ?? _tracks(), defaultHeight: 28);

void main() {
  group('heights', () {
    test('a lane without one takes the default', () {
      expect(_rows().heightOf(0), 28);
      expect(_rows().heightOf(2), 28);
    });

    test('a lane with one takes its own', () {
      expect(_rows().heightOf(1), 60);
    });

    test('stack into tops', () {
      final rows = _rows();

      expect(rows.topOf(0), 0);
      expect(rows.topOf(1), 28);
      expect(rows.topOf(2), 88);
      expect(rows.totalHeight, 116);
    });

    test('an empty timeline is zero tall and has no rows', () {
      final rows = _rows(tracks: const []);

      expect(rows.totalHeight, 0);
      expect(rows.rowAt(0), isNull);
    });
  });

  group('the row under a pixel', () {
    test('is the one whose band holds it', () {
      final rows = _rows();

      expect(rows.rowAt(0), 0);
      expect(rows.rowAt(27.9), 0);
      expect(rows.rowAt(28), 1);
      expect(rows.rowAt(87.9), 1);
      expect(rows.rowAt(88), 2);
    });

    test('is nothing above the first row or below the last', () {
      final rows = _rows();

      expect(rows.rowAt(-1), isNull);
      expect(rows.rowAt(116), isNull);
    });

    test('clamps to the nearest row when a drag runs off either end', () {
      // A pointer dragged off the top is unambiguously aimed at the topmost
      // lane; answering "none" would snap the bar back under a pointer that
      // never left.
      final rows = _rows();

      expect(rows.clampedRowAt(-500), 0);
      expect(rows.clampedRowAt(5000), 2);
      expect(rows.clampedRowAt(50), 1);
    });
  });

  group('what a viewport can see', () {
    test('is every row when they all fit', () {
      expect(_rows().visibleRange(0, 200), (first: 0, last: 2));
    });

    test('is only the rows the viewport crosses', () {
      // 40 pixels from the top of a 28-tall first row reaches into the second
      // and no further.
      expect(_rows().visibleRange(0, 40), (first: 0, last: 1));
    });

    test('follows the scroll', () {
      expect(_rows().visibleRange(90, 20), (first: 2, last: 2));
    });

    test('is bounded by the viewport rather than by the model', () {
      // The point of the whole thing: a thousand lanes cost the same as the
      // handful that fit on screen.
      final rows = TimelineLaneRows(
        tracks: [for (var i = 0; i < 1000; i++) TimelineTrack(id: '$i', label: '$i')],
        defaultHeight: 28,
      );

      final range = rows.visibleRange(0, 200)!;

      expect(range.last - range.first + 1, lessThan(12));
    });

    test('never reaches past the last row', () {
      final rows = _rows();

      expect(rows.visibleRange(0, 10000), (first: 0, last: 2));
      expect(rows.visibleRange(10000, 100), (first: 2, last: 2));
    });

    test('an empty timeline sees nothing, and says so rather than guessing', () {
      expect(_rows(tracks: const []).visibleRange(0, 200), isNull);
    });
  });
}
