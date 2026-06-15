import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/audio/runtime/frame_list_beat_grid.dart';

void main() {
  group('FrameListBeatGrid', () {
    test('beatFrames exposes the grid frames in order', () {
      final grid = FrameListBeatGrid([0, 15, 30, 45]);
      expect(grid.beatFrames, [0, 15, 30, 45]);
    });

    test('firstBeatAtOrAfter returns the next beat at or after a frame', () {
      final grid = FrameListBeatGrid([0, 15, 30, 45]);
      expect(grid.firstBeatAtOrAfter(0), 0);
      expect(grid.firstBeatAtOrAfter(16), 30);
      expect(grid.firstBeatAtOrAfter(46), isNull);
    });

    test('every skips beats by the stride', () {
      final grid = FrameListBeatGrid([0, 10, 20, 30]);
      // every: 2 visits indices 0, 2, ... so 10 is skipped, the next is 20.
      expect(grid.firstBeatAtOrAfter(5, every: 2), 20);
    });
  });
}
