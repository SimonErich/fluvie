import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/timing.dart';

String _describe(Timing timing) => switch (timing) {
  Tween() => 'tween',
  Spring() => 'spring',
};

(double, double, double, double) _params(Spring s) =>
    (s.stiffness, s.damping, s.mass, s.initialVelocity);

/// Builds a [Spring] from runtime values so constructor asserts fire at run
/// time instead of failing const evaluation.
Spring _spring({double stiffness = 180, double damping = 12, double mass = 1}) =>
    Spring(stiffness: stiffness, damping: damping, mass: mass);

void main() {
  group('Tween', () {
    test('defaults ease to Ease.smooth', () {
      const tween = Tween(Time.seconds(0.3));
      expect(tween.ease, same(Ease.smooth));
    });

    test('stores its duration and ease', () {
      const tween = Tween(Time.frames(12), ease: Ease.snappy);
      expect(tween.duration, const Time.frames(12));
      expect(tween.ease, same(Ease.snappy));
    });

    test('value equality and hashCode', () {
      const a = Tween(Time.seconds(0.5), ease: Ease.out);
      const b = Tween(Time.seconds(0.5), ease: Ease.out);
      const c = Tween(Time.seconds(0.5), ease: Ease.in_);
      const d = Tween(Time.seconds(0.6), ease: Ease.out);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals(d)));
    });

    test('toString names the duration and ease', () {
      const tween = Tween(Time.seconds(0.5));
      expect(tween.toString(), contains('Tween'));
      expect(tween.toString(), contains('Time.seconds(0.5)'));
    });
  });

  group('Spring', () {
    test('defaults to stiffness 180, damping 12, mass 1, initialVelocity 0', () {
      const spring = Spring();
      expect(spring.stiffness, 180);
      expect(spring.damping, 12);
      expect(spring.mass, 1);
      expect(spring.initialVelocity, 0);
    });

    test('presets carry their documented parameter sets', () {
      expect(_params(Spring.gentle), (120.0, 14.0, 1.0, 0.0));
      expect(_params(Spring.snappy), (260.0, 20.0, 1.0, 0.0));
      expect(_params(Spring.bouncy), (180.0, 10.0, 1.0, 0.0));
      expect(_params(Spring.stiff), (400.0, 28.0, 1.0, 0.0));
    });

    test('rejects non-positive stiffness', () {
      expect(() => _spring(stiffness: 0), throwsAssertionError);
      expect(() => _spring(stiffness: -1), throwsAssertionError);
    });

    test('rejects non-positive mass', () {
      expect(() => _spring(mass: 0), throwsAssertionError);
      expect(() => _spring(mass: -1), throwsAssertionError);
    });

    test('rejects negative damping but allows zero', () {
      expect(() => _spring(damping: -1), throwsAssertionError);
      expect(_spring(damping: 0).damping, 0);
    });

    test('value equality and hashCode', () {
      const a = Spring(stiffness: 200, damping: 15, mass: 2, initialVelocity: 1);
      const b = Spring(stiffness: 200, damping: 15, mass: 2, initialVelocity: 1);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(const Spring(stiffness: 201, damping: 15, mass: 2))));
      expect(a, isNot(equals(const Spring(stiffness: 200, damping: 16, mass: 2))));
      expect(a, isNot(equals(const Spring(stiffness: 200, damping: 15, mass: 3))));
      expect(
        a,
        isNot(equals(const Spring(stiffness: 200, damping: 15, mass: 2, initialVelocity: 2))),
      );
    });

    test('toString lists all four parameters', () {
      const spring = Spring();
      expect(spring.toString(), contains('Spring'));
      expect(spring.toString(), contains('stiffness'));
      expect(spring.toString(), contains('damping'));
      expect(spring.toString(), contains('mass'));
      expect(spring.toString(), contains('initialVelocity'));
    });
  });

  group('Timing', () {
    test('is sealed: a switch over Tween and Spring is exhaustive', () {
      expect(_describe(const Tween(Time.seconds(1))), 'tween');
      expect(_describe(const Spring()), 'spring');
    });
  });
}
