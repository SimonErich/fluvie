// The tone curve every colour surface shares: a monotone cubic through the
// control points, clamped to the unit range, with an exact identity. Pinned
// once here, because the master curve, the per-channel curves and the
// editor's curve editor all read this one evaluator.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

void main() {
  group('the identity', () {
    test('is exactly the diagonal', () {
      const identity = ToneCurve.identity;

      for (var i = 0; i <= 10; i++) {
        final x = i / 10;
        expect(identity.at(x), x);
      }
    });

    test('is what two diagonal points build', () {
      final curve = ToneCurve.fromPoints(const [(0, 0), (1, 1)]);

      expect(curve.at(0.25), 0.25);
      expect(curve.at(0.75), 0.75);
      expect(curve.isIdentity, isTrue);
    });
  });

  group('through the points', () {
    test('passes through every control point exactly', () {
      final curve = ToneCurve.fromPoints(const [(0, 0.1), (0.4, 0.6), (1, 0.9)]);

      expect(curve.at(0), 0.1);
      expect(curve.at(0.4), closeTo(0.6, 1e-12));
      expect(curve.at(1), 0.9);
    });

    test('stays monotone between increasing points, without overshoot', () {
      // The classic failure of a natural cubic: a steep segment next to a
      // flat one rings. Fritsch-Carlson slopes must not.
      final curve = ToneCurve.fromPoints(const [(0, 0), (0.3, 0.05), (0.5, 0.9), (1, 1)]);

      var previous = curve.at(0);
      for (var i = 1; i <= 200; i++) {
        final value = curve.at(i / 200);
        expect(value, greaterThanOrEqualTo(previous - 1e-12));
        expect(value, inInclusiveRange(0, 1));
        previous = value;
      }
    });

    test('holds flat across a plateau', () {
      final curve = ToneCurve.fromPoints(const [(0, 0.5), (0.5, 0.5), (1, 1)]);

      expect(curve.at(0.25), closeTo(0.5, 1e-12));
    });
  });

  group('the edges', () {
    test('clamps outside the first and last point', () {
      final curve = ToneCurve.fromPoints(const [(0.2, 0.3), (0.8, 0.7)]);

      expect(curve.at(0), 0.3);
      expect(curve.at(1), 0.7);
      expect(curve.at(-5), 0.3);
      expect(curve.at(5), 0.7);
    });

    test('clamps a point authored past the unit range', () {
      final curve = ToneCurve.fromPoints(const [(0, -0.5), (1, 1.5)]);

      expect(curve.at(0), 0);
      expect(curve.at(1), 1);
    });
  });

  group('what it refuses', () {
    test('fewer than two points', () {
      expect(() => ToneCurve.fromPoints(const [(0.5, 0.5)]), throwsArgumentError);
      expect(() => ToneCurve.fromPoints(const []), throwsArgumentError);
    });

    test('positions that do not strictly increase', () {
      expect(
        () => ToneCurve.fromPoints(const [(0, 0), (0.5, 0.4), (0.5, 0.6), (1, 1)]),
        throwsArgumentError,
      );
      expect(() => ToneCurve.fromPoints(const [(0.8, 0), (0.2, 1)]), throwsArgumentError);
    });
  });

  group('hostile numbers', () {
    test('a denormal step next to a steep one stays monotone, never NaN', () {
      // The slope limiter divides slopes by secants; a ~1e308 ratio
      // overflows to infinity and a NaN would clamp silently to 1.
      final curve = ToneCurve.fromPoints(const [
        (0, 0),
        (0.5, 5e-324),
        (0.5000000001, 1),
        (1, 1),
      ]);

      expect(curve.at(0.25), lessThan(0.01));
      var previous = curve.at(0);
      for (var i = 1; i <= 100; i++) {
        final value = curve.at(i / 100);
        expect(value.isNaN, isFalse);
        expect(value, greaterThanOrEqualTo(previous - 1e-12));
        previous = value;
      }
    });

    test('a non-finite point is refused', () {
      expect(
        () => ToneCurve.fromPoints(const [(0, 0), (double.infinity, 1)]),
        throwsArgumentError,
      );
      expect(
        () => ToneCurve.fromPoints(const [(0, double.nan), (1, 1)]),
        throwsArgumentError,
      );
    });
  });

  group('sampling', () {
    test('bakes n evenly spaced reads, ends included', () {
      final samples = ToneCurve.identity.sample(256);

      expect(samples, hasLength(256));
      expect(samples.first, 0);
      expect(samples.last, 1);
      expect(samples[128], closeTo(128 / 255, 1e-12));
    });
  });
}
