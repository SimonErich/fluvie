import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/utils/frame_range.dart';

void main() {
  group('FrameRange', () {
    group('constructor', () {
      test('creates valid range', () {
        final range = FrameRange(30, 120);
        expect(range.start, 30);
        expect(range.end, 120);
      });

      test('throws when end equals start', () {
        expect(() => FrameRange(30, 30), throwsA(isA<AssertionError>()));
      });

      test('throws when end is less than start', () {
        expect(() => FrameRange(120, 30), throwsA(isA<AssertionError>()));
      });
    });

    group('duration', () {
      test('calculates duration correctly', () {
        final range = FrameRange(30, 120);
        expect(range.duration, 90);
      });

      test('works with zero start', () {
        final range = FrameRange(0, 100);
        expect(range.duration, 100);
      });
    });

    group('durationInSeconds', () {
      test('converts to seconds at 30fps', () {
        final range = FrameRange(0, 90);
        expect(range.durationInSeconds(30), 3.0);
      });

      test('converts to seconds at 60fps', () {
        final range = FrameRange(0, 120);
        expect(range.durationInSeconds(60), 2.0);
      });
    });

    group('contains', () {
      test('returns false for frame before start', () {
        final range = FrameRange(30, 120);
        expect(range.contains(29), false);
      });

      test('returns true for frame at start', () {
        final range = FrameRange(30, 120);
        expect(range.contains(30), true);
      });

      test('returns true for frame in middle', () {
        final range = FrameRange(30, 120);
        expect(range.contains(75), true);
      });

      test('returns true for frame just before end', () {
        final range = FrameRange(30, 120);
        expect(range.contains(119), true);
      });

      test('returns false for frame at end (exclusive)', () {
        final range = FrameRange(30, 120);
        expect(range.contains(120), false);
      });

      test('returns false for frame after end', () {
        final range = FrameRange(30, 120);
        expect(range.contains(150), false);
      });
    });

    group('progress', () {
      test('returns 0.0 for negative frame', () {
        final range = FrameRange(0, 100);
        expect(range.progress(-10), 0.0);
      });

      test('returns 0.0 for frame at start', () {
        final range = FrameRange(0, 100);
        expect(range.progress(0), 0.0);
      });

      test('returns 0.25 for quarter progress', () {
        final range = FrameRange(0, 100);
        expect(range.progress(25), 0.25);
      });

      test('returns 0.5 for half progress', () {
        final range = FrameRange(0, 100);
        expect(range.progress(50), 0.5);
      });

      test('returns 0.75 for three-quarter progress', () {
        final range = FrameRange(0, 100);
        expect(range.progress(75), 0.75);
      });

      test('returns 1.0 for frame at end', () {
        final range = FrameRange(0, 100);
        expect(range.progress(100), 1.0);
      });

      test('returns 1.0 for frame after end', () {
        final range = FrameRange(0, 100);
        expect(range.progress(150), 1.0);
      });

      test('works with non-zero start', () {
        final range = FrameRange(30, 130);
        expect(range.progress(30), 0.0);
        expect(range.progress(80), 0.5);
        expect(range.progress(130), 1.0);
      });
    });

    group('unclampedProgress', () {
      test('returns negative for frame before start', () {
        final range = FrameRange(100, 200);
        expect(range.unclampedProgress(50), -0.5);
      });

      test('returns value > 1 for frame after end', () {
        final range = FrameRange(0, 100);
        expect(range.unclampedProgress(150), 1.5);
      });
    });

    group('fromDuration', () {
      test('creates range from start and duration', () {
        final range = FrameRange.fromDuration(60, 90);
        expect(range.start, 60);
        expect(range.end, 150);
        expect(range.duration, 90);
      });

      test('throws for non-positive duration', () {
        expect(
          () => FrameRange.fromDuration(0, 0),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => FrameRange.fromDuration(0, -10),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('fromSeconds', () {
      test('creates range from seconds at 30fps', () {
        final range = FrameRange.fromSeconds(30, 1.0, 3.0);
        expect(range.start, 30);
        expect(range.end, 90);
        expect(range.duration, 60);
      });

      test('creates range from seconds at 60fps', () {
        final range = FrameRange.fromSeconds(60, 0.5, 2.0);
        expect(range.start, 30);
        expect(range.end, 120);
      });

      test('throws for non-positive fps', () {
        expect(
          () => FrameRange.fromSeconds(0, 0.0, 1.0),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws when endSec <= startSec', () {
        expect(
          () => FrameRange.fromSeconds(30, 2.0, 1.0),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => FrameRange.fromSeconds(30, 1.0, 1.0),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('fromSecondsDuration', () {
      test('creates range from start frame and duration in seconds', () {
        final range = FrameRange.fromSecondsDuration(30, 60, 2.0);
        expect(range.start, 60);
        expect(range.end, 120);
      });
    });

    group('offset', () {
      test('shifts range by positive frames', () {
        final range = FrameRange(0, 100);
        final shifted = range.offset(50);
        expect(shifted.start, 50);
        expect(shifted.end, 150);
        expect(shifted.duration, 100); // Duration unchanged
      });

      test('shifts range by negative frames', () {
        final range = FrameRange(100, 200);
        final shifted = range.offset(-50);
        expect(shifted.start, 50);
        expect(shifted.end, 150);
      });
    });

    group('shiftStart', () {
      test('shifts only start', () {
        final range = FrameRange(0, 100);
        final shifted = range.shiftStart(20);
        expect(shifted.start, 20);
        expect(shifted.end, 100);
        expect(shifted.duration, 80);
      });
    });

    group('shiftEnd', () {
      test('shifts only end', () {
        final range = FrameRange(0, 100);
        final shifted = range.shiftEnd(20);
        expect(shifted.start, 0);
        expect(shifted.end, 120);
        expect(shifted.duration, 120);
      });
    });

    group('expand', () {
      test('expands range on both sides', () {
        final range = FrameRange(50, 150);
        final expanded = range.expand(10);
        expect(expanded.start, 40);
        expect(expanded.end, 160);
        expect(expanded.duration, 120);
      });
    });

    group('contract', () {
      test('contracts range on both sides', () {
        final range = FrameRange(0, 100);
        final contracted = range.contract(10);
        expect(contracted.start, 10);
        expect(contracted.end, 90);
        expect(contracted.duration, 80);
      });

      test('throws when contraction would invert range', () {
        final range = FrameRange(0, 20);
        expect(() => range.contract(15), throwsA(isA<ArgumentError>()));
      });
    });

    group('overlaps', () {
      test('returns true for overlapping ranges', () {
        final range1 = FrameRange(0, 100);
        final range2 = FrameRange(50, 150);
        expect(range1.overlaps(range2), true);
        expect(range2.overlaps(range1), true);
      });

      test('returns false for adjacent ranges', () {
        final range1 = FrameRange(0, 100);
        final range2 = FrameRange(100, 200);
        expect(range1.overlaps(range2), false);
      });

      test('returns false for non-overlapping ranges', () {
        final range1 = FrameRange(0, 50);
        final range2 = FrameRange(100, 150);
        expect(range1.overlaps(range2), false);
      });

      test('returns true when one range contains another', () {
        final outer = FrameRange(0, 200);
        final inner = FrameRange(50, 150);
        expect(outer.overlaps(inner), true);
        expect(inner.overlaps(outer), true);
      });
    });

    group('intersection', () {
      test('returns intersection for overlapping ranges', () {
        final range1 = FrameRange(0, 100);
        final range2 = FrameRange(50, 150);
        final intersection = range1.intersection(range2);
        expect(intersection, isNotNull);
        expect(intersection!.start, 50);
        expect(intersection.end, 100);
      });

      test('returns null for non-overlapping ranges', () {
        final range1 = FrameRange(0, 50);
        final range2 = FrameRange(100, 150);
        expect(range1.intersection(range2), isNull);
      });
    });

    group('union', () {
      test('returns union of two ranges', () {
        final range1 = FrameRange(0, 100);
        final range2 = FrameRange(50, 150);
        final union = range1.union(range2);
        expect(union.start, 0);
        expect(union.end, 150);
      });
    });

    group('splitAt', () {
      test('splits range at given frame', () {
        final range = FrameRange(0, 100);
        final split = range.splitAt(40);
        expect(split, isNotNull);
        expect(split!.$1.start, 0);
        expect(split.$1.end, 40);
        expect(split.$2.start, 40);
        expect(split.$2.end, 100);
      });

      test('returns null when frame is at start', () {
        final range = FrameRange(0, 100);
        expect(range.splitAt(0), isNull);
      });

      test('returns null when frame is at end', () {
        final range = FrameRange(0, 100);
        expect(range.splitAt(100), isNull);
      });

      test('returns null when frame is outside range', () {
        final range = FrameRange(50, 100);
        expect(range.splitAt(25), isNull);
        expect(range.splitAt(150), isNull);
      });
    });

    group('keyframes', () {
      test('generates evenly spaced keyframes', () {
        final range = FrameRange(0, 100);
        final keyframes = range.keyframes(5);
        expect(keyframes, [0, 25, 50, 75, 100]);
      });

      test('generates 2 keyframes at start and end', () {
        final range = FrameRange(0, 100);
        final keyframes = range.keyframes(2);
        expect(keyframes, [0, 100]);
      });

      test('works with non-zero start', () {
        final range = FrameRange(50, 150);
        final keyframes = range.keyframes(3);
        expect(keyframes, [50, 100, 150]);
      });

      test('throws for count less than 2', () {
        final range = FrameRange(0, 100);
        expect(() => range.keyframes(1), throwsA(isA<ArgumentError>()));
      });
    });

    group('localToGlobal', () {
      test('converts local frame to global', () {
        final range = FrameRange(100, 200);
        expect(range.localToGlobal(0), 100);
        expect(range.localToGlobal(50), 150);
        expect(range.localToGlobal(100), 200);
      });
    });

    group('globalToLocal', () {
      test('converts global frame to local', () {
        final range = FrameRange(100, 200);
        expect(range.globalToLocal(100), 0);
        expect(range.globalToLocal(150), 50);
        expect(range.globalToLocal(200), 100);
      });

      test('returns negative for frame before start', () {
        final range = FrameRange(100, 200);
        expect(range.globalToLocal(50), -50);
      });
    });

    group('equality', () {
      test('equal ranges are equal', () {
        final range1 = FrameRange(0, 100);
        final range2 = FrameRange(0, 100);
        expect(range1, equals(range2));
        expect(range1.hashCode, equals(range2.hashCode));
      });

      test('different ranges are not equal', () {
        final range1 = FrameRange(0, 100);
        final range2 = FrameRange(0, 150);
        expect(range1, isNot(equals(range2)));
      });
    });

    group('toString', () {
      test('returns readable string', () {
        final range = FrameRange(30, 120);
        expect(range.toString(), 'FrameRange(30, 120)');
      });
    });
  });
}
