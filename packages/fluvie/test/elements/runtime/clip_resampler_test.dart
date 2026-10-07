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
  double speed = 1,
}) => resampleClipFrame(
  compFrame: compFrame,
  windowStart: windowStart,
  compFps: compFps,
  srcFps: srcFps,
  trimStartFrames: trimStartFrames,
  trimEndFrames: trimEndFrames,
  speed: speed,
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

  group('speed retimes the source', () {
    test('half speed advances one source frame every two composition frames', () {
      expect(_resample(compFrame: 0, trimEndFrames: 30, speed: 0.5), 0);
      expect(_resample(compFrame: 1, trimEndFrames: 30, speed: 0.5), 0);
      expect(_resample(compFrame: 2, trimEndFrames: 30, speed: 0.5), 1);
      expect(_resample(compFrame: 9, trimEndFrames: 30, speed: 0.5), 4);
    });

    test('double speed advances two source frames per composition frame', () {
      expect(_resample(compFrame: 0, trimEndFrames: 60, speed: 2), 0);
      expect(_resample(compFrame: 1, trimEndFrames: 60, speed: 2), 2);
      expect(_resample(compFrame: 7, trimEndFrames: 60, speed: 2), 14);
    });

    test('speed 1 is exactly the unretimed rule', () {
      // Held in a variable so the analyzer does not read it as a redundant
      // literal: passing the default explicitly is the point of the test.
      final sourceSpeed = double.parse('1');
      for (final frame in [0, 1, 7, 29]) {
        expect(
          _resample(compFrame: frame, trimEndFrames: 30, speed: sourceSpeed),
          _resample(compFrame: frame, trimEndFrames: 30),
        );
      }
    });

    test('a fast clip still holds on its last frame rather than reading past it', () {
      // The clamp is what makes a 2x clip in a long window freeze instead of
      // running off the end of the trim.
      expect(_resample(compFrame: 40, trimEndFrames: 30, speed: 2), 29);
    });

    test('reverse counts back from the last source frame', () {
      expect(_resample(compFrame: 0, trimEndFrames: 30, speed: -1), 29);
      expect(_resample(compFrame: 1, trimEndFrames: 30, speed: -1), 28);
      expect(_resample(compFrame: 29, trimEndFrames: 30, speed: -1), 0);
    });

    test('reverse clamps at the trim start once it has run out', () {
      expect(_resample(compFrame: 45, trimEndFrames: 30, speed: -1), 0);
    });

    test('reverse honours the trim, not the whole source', () {
      // Trim 10..20 reversed opens on source 19 and walks down to 10.
      expect(
        _resample(compFrame: 0, trimStartFrames: 10, trimEndFrames: 20, speed: -1),
        19,
      );
      expect(
        _resample(compFrame: 9, trimStartFrames: 10, trimEndFrames: 20, speed: -1),
        10,
      );
      expect(
        _resample(compFrame: 30, trimStartFrames: 10, trimEndFrames: 20, speed: -1),
        10,
        reason: 'past the end it holds the trim start, never below it',
      );
    });

    test('half speed reversed halves the walk back', () {
      expect(_resample(compFrame: 0, trimEndFrames: 30, speed: -0.5), 29);
      expect(_resample(compFrame: 1, trimEndFrames: 30, speed: -0.5), 29);
      expect(_resample(compFrame: 2, trimEndFrames: 30, speed: -0.5), 28);
    });
  });
}
