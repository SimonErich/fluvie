// WI-14 (D9): the pure clip frame resampler. srcFrame =
// floor((compFrame - windowStart) / compFps * srcFps) + trimStartFrames,
// clamped to [trimStartFrames, trimEndFrames - 1]. No goldens — exhaustive
// unit coverage of the floor rule, trim offset, both clamps, and determinism.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/elements/runtime/clip_resampler.dart';

int _resample({
  required int compFrame,
  required int trimEndFrames,
  int windowStart = 0,
  int compFps = 30,
  double srcFps = 30,
  int trimStartFrames = 0,
}) => resampleClipFrame(
  compFrame: compFrame,
  windowStart: windowStart,
  compFps: compFps,
  srcFps: srcFps,
  trimStartFrames: trimStartFrames,
  trimEndFrames: trimEndFrames,
);

void main() {
  group('identity (compFps == srcFps, no trim)', () {
    test('window start maps to source frame 0', () {
      expect(_resample(compFrame: 0, trimEndFrames: 30), 0);
    });

    test('an interior frame maps one-to-one', () {
      expect(_resample(compFrame: 12, trimEndFrames: 30), 12);
    });

    test('windowStart offsets the source space', () {
      expect(_resample(compFrame: 47, windowStart: 40, trimEndFrames: 30), 7);
    });
  });

  group('fps mismatch floors (holds frames)', () {
    test('24fps source under a 30fps comp holds via floor', () {
      // elapsed 1 -> 1/30*24 = 0.8 -> floor 0 (the source holds frame 0)
      expect(_resample(compFrame: 1, srcFps: 24, trimEndFrames: 24), 0);
      // elapsed 2 -> 2/30*24 = 1.6 -> floor 1
      expect(_resample(compFrame: 2, srcFps: 24, trimEndFrames: 24), 1);
      // elapsed 5 -> 5/30*24 = 4.0 -> floor 4
      expect(_resample(compFrame: 5, srcFps: 24, trimEndFrames: 24), 4);
    });

    test('60fps source under a 30fps comp advances two source frames', () {
      // elapsed 3 -> 3/30*60 = 6.0 -> floor 6
      expect(_resample(compFrame: 3, srcFps: 60, trimEndFrames: 120), 6);
    });

    test('floor never rounds up past the elapsed position', () {
      // elapsed 7 -> 7/30*24 = 5.6 -> floor 5 (not 6)
      expect(_resample(compFrame: 7, srcFps: 24, trimEndFrames: 24), 5);
    });
  });

  group('trim offset', () {
    test('trimStartFrames shifts the read into the source', () {
      // elapsed 4 -> 4 + 90 = 94 (trim starts at source frame 90)
      expect(
        _resample(compFrame: 4, trimStartFrames: 90, trimEndFrames: 210),
        94,
      );
    });

    test('the first window frame reads exactly trimStartFrames', () {
      expect(
        _resample(compFrame: 0, trimStartFrames: 90, trimEndFrames: 210),
        90,
      );
    });
  });

  group('clamping', () {
    test('a frame before the window clamps to trimStartFrames', () {
      // compFrame < windowStart -> negative elapsed -> clamp low
      expect(
        _resample(compFrame: 30, windowStart: 50, trimStartFrames: 5, trimEndFrames: 60),
        5,
      );
    });

    test('a frame past the trim end clamps to trimEndFrames - 1', () {
      // a long-lived window holding past the source: clamp to the last frame
      expect(_resample(compFrame: 1000, trimEndFrames: 30), 29);
    });

    test('clamp respects the trimmed end, not the raw source length', () {
      expect(
        _resample(compFrame: 1000, trimStartFrames: 10, trimEndFrames: 20),
        19,
      );
    });
  });

  group('determinism', () {
    test('the same inputs always yield the same source frame', () {
      for (var i = 0; i < 50; i++) {
        expect(
          _resample(
            compFrame: 13,
            windowStart: 3,
            srcFps: 24,
            trimStartFrames: 2,
            trimEndFrames: 50,
          ),
          _resample(
            compFrame: 13,
            windowStart: 3,
            srcFps: 24,
            trimStartFrames: 2,
            trimEndFrames: 50,
          ),
        );
      }
    });
  });
}
