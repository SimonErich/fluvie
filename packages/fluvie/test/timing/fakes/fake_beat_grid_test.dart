import 'package:flutter_test/flutter_test.dart';

import 'fake_beat_grid.dart';

void main() {
  group('FakeBeatGrid', () {
    test('a frame exactly on a beat returns that beat', () {
      final grid = FakeBeatGrid([0, 10, 20, 30]);
      expect(grid.firstBeatAtOrAfter(20), 20);
    });

    test('a frame between beats returns the next beat', () {
      final grid = FakeBeatGrid([0, 10, 20, 30]);
      expect(grid.firstBeatAtOrAfter(15), 20);
    });

    test('every: 2 skips the odd-indexed beats', () {
      final grid = FakeBeatGrid([0, 10, 20, 30]);
      // Qualifying beats are indices 0, 2, ... → frames 0 and 20.
      expect(grid.firstBeatAtOrAfter(5, every: 2), 20);
    });

    test('a frame past the last qualifying beat returns null', () {
      final grid = FakeBeatGrid([0, 10, 20, 30]);
      expect(grid.firstBeatAtOrAfter(31), isNull);
      expect(grid.firstBeatAtOrAfter(25, every: 4), isNull);
    });

    test('an empty grid returns null', () {
      final grid = FakeBeatGrid(const []);
      expect(grid.firstBeatAtOrAfter(0), isNull);
    });

    test('everyInterval lays beats at regular frames from zero', () {
      final grid = FakeBeatGrid.everyInterval(15, totalFrames: 60);
      // Beats at 0, 15, 30, 45 (60 is past the end of the clip).
      expect(grid.firstBeatAtOrAfter(0), 0);
      expect(grid.firstBeatAtOrAfter(1), 15);
      expect(grid.firstBeatAtOrAfter(46), isNull);
    });
  });
}
