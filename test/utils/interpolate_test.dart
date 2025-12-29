import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

void main() {
  group('interpolate', () {
    group('basic interpolation', () {
      test('interpolates at midpoint', () {
        final result = interpolate(15, [0, 30], [0.0, 100.0]);
        expect(result, 50.0);
      });

      test('interpolates at start', () {
        final result = interpolate(0, [0, 30], [0.0, 100.0]);
        expect(result, 0.0);
      });

      test('interpolates at end', () {
        final result = interpolate(30, [0, 30], [0.0, 100.0]);
        expect(result, 100.0);
      });

      test('interpolates at quarter point', () {
        final result = interpolate(10, [0, 40], [0.0, 100.0]);
        expect(result, 25.0);
      });

      test('interpolates negative values', () {
        final result = interpolate(50, [0, 100], [-50.0, 50.0]);
        expect(result, 0.0);
      });

      test('interpolates decreasing values', () {
        final result = interpolate(50, [0, 100], [100.0, 0.0]);
        expect(result, 50.0);
      });
    });

    group('multi-segment interpolation', () {
      test('interpolates across multiple segments', () {
        // Keyframes: 0->0, 30->100, 60->50
        expect(interpolate(0, [0, 30, 60], [0.0, 100.0, 50.0]), 0.0);
        expect(interpolate(15, [0, 30, 60], [0.0, 100.0, 50.0]), 50.0);
        expect(interpolate(30, [0, 30, 60], [0.0, 100.0, 50.0]), 100.0);
        expect(interpolate(45, [0, 30, 60], [0.0, 100.0, 50.0]), 75.0);
        expect(interpolate(60, [0, 30, 60], [0.0, 100.0, 50.0]), 50.0);
      });

      test('handles many segments', () {
        final result = interpolate(
          5,
          [0, 10, 20, 30, 40],
          [0.0, 100.0, 50.0, 75.0, 25.0],
        );
        expect(result, 50.0); // Midpoint of first segment
      });
    });

    group('clamping behavior (default)', () {
      test('clamps before range', () {
        final result = interpolate(-10, [0, 30], [0.0, 100.0]);
        expect(result, 0.0);
      });

      test('clamps after range', () {
        final result = interpolate(50, [0, 30], [0.0, 100.0]);
        expect(result, 100.0);
      });
    });

    group('extrapolation', () {
      test('extrapolates before range', () {
        final result = interpolate(
          -10,
          [0, 30],
          [0.0, 100.0],
          extrapolate: true,
        );
        // Slope = 100/30 = 3.33..., at -10: 0 + 3.33 * (-10) = -33.33...
        expect(result, closeTo(-33.33, 0.01));
      });

      test('extrapolates after range', () {
        final result = interpolate(
          40,
          [0, 30],
          [0.0, 100.0],
          extrapolate: true,
        );
        // Slope = 100/30 = 3.33..., at 40: 100 + 3.33 * 10 = 133.33...
        expect(result, closeTo(133.33, 0.01));
      });
    });

    group('curve support', () {
      test('applies linear curve by default', () {
        final result = interpolate(15, [0, 30], [0.0, 100.0]);
        expect(result, 50.0);
      });

      test('applies easeIn curve', () {
        final result = interpolate(
          15,
          [0, 30],
          [0.0, 100.0],
          curve: Curves.easeIn,
        );
        // easeIn starts slow, so at midpoint progress should be < 50%
        expect(result, lessThan(50.0));
      });

      test('applies easeOut curve', () {
        final result = interpolate(
          15,
          [0, 30],
          [0.0, 100.0],
          curve: Curves.easeOut,
        );
        // easeOut ends slow, so at midpoint progress should be > 50%
        expect(result, greaterThan(50.0));
      });

      test('applies easeInOut curve symmetrically', () {
        final result = interpolate(
          15,
          [0, 30],
          [0.0, 100.0],
          curve: Curves.easeInOut,
        );
        // easeInOut at midpoint should be close to 50%
        expect(result, closeTo(50.0, 5.0));
      });
    });

    group('validation', () {
      test('throws on mismatched lengths', () {
        expect(
          () => interpolate(10, [0, 30], [0.0, 50.0, 100.0]),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws on single element', () {
        expect(
          () => interpolate(10, [0], [0.0]),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws on empty lists', () {
        expect(() => interpolate(10, [], []), throwsA(isA<ArgumentError>()));
      });

      test('throws on unsorted input range', () {
        expect(
          () => interpolate(10, [30, 0], [100.0, 0.0]),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('allows equal consecutive values in input range', () {
        // This should not throw - equal values are valid (no progress in segment)
        final result = interpolate(
          10,
          [0, 10, 10, 20],
          [0.0, 50.0, 50.0, 100.0],
        );
        expect(result, 50.0);
      });
    });

    group('edge cases', () {
      test('handles frame at exact keyframe', () {
        final result = interpolate(30, [0, 30, 60], [0.0, 100.0, 50.0]);
        expect(result, 100.0);
      });

      test('handles very large frame numbers', () {
        final result = interpolate(1000000, [0, 100], [0.0, 1.0]);
        expect(result, 1.0);
      });

      test('handles negative frame numbers', () {
        final result = interpolate(-1000, [0, 100], [0.0, 1.0]);
        expect(result, 0.0);
      });

      test('handles very small value differences', () {
        final result = interpolate(50, [0, 100], [0.0, 0.001]);
        expect(result, closeTo(0.0005, 0.00001));
      });
    });
  });

  group('lerpValue', () {
    test('interpolates at midpoint', () {
      expect(lerpValue(0.5, 0.0, 100.0), 50.0);
    });

    test('interpolates at start', () {
      expect(lerpValue(0.0, 0.0, 100.0), 0.0);
    });

    test('interpolates at end', () {
      expect(lerpValue(1.0, 0.0, 100.0), 100.0);
    });

    test('clamps progress below 0', () {
      expect(lerpValue(-0.5, 0.0, 100.0), 0.0);
    });

    test('clamps progress above 1', () {
      expect(lerpValue(1.5, 0.0, 100.0), 100.0);
    });

    test('applies curve', () {
      final result = lerpValue(0.5, 0.0, 100.0, curve: Curves.easeIn);
      expect(result, lessThan(50.0));
    });
  });
}
