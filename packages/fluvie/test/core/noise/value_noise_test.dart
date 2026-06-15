import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/noise/noise_source.dart';
import 'package:fluvie/src/core/noise/value_noise.dart';

void main() {
  group('ValueNoise — valueForSeed (WI-9, D2)', () {
    test('is a NoiseSource', () {
      expect(const ValueNoise(), isA<NoiseSource>());
    });

    test('is stable across calls and across instances', () {
      const a = ValueNoise();
      const b = ValueNoise();
      final first = a.valueForSeed('leaf-7');
      expect(a.valueForSeed('leaf-7'), first);
      expect(b.valueForSeed('leaf-7'), first);
    });

    test('pins the literal scalar so the seam survives the P14 rewire', () {
      // Golden the exact double: P14 wires ctx.noise but must not change the
      // math, so this value is the contract every seeded golden depends on.
      expect(const ValueNoise().valueForSeed('leaf-7'), _leaf7);
    });

    test('different seeds give different values', () {
      const noise = ValueNoise();
      final values = {
        for (final seed in ['a', 'b', 'c', 'p-0', 'p-1', 'p-2', 'leaf-7']) noise.valueForSeed(seed),
      };
      expect(values.length, 7, reason: 'all seven seeds must map to distinct scalars');
    });

    test('stays inside [0, 1] for many seeds', () {
      const noise = ValueNoise();
      for (var i = 0; i < 500; i++) {
        final value = noise.valueForSeed('seed-$i');
        expect(value, inInclusiveRange(0, 1));
      }
    });
  });

  group('ValueNoise — noise1', () {
    test('is bounded to [0, 1]', () {
      const noise = ValueNoise();
      for (var i = 0; i < 200; i++) {
        expect(noise.noise1(i * 0.37 - 30), inInclusiveRange(0, 1));
      }
    });

    test('is continuous: adjacent inputs read close', () {
      const noise = ValueNoise();
      var previous = noise.noise1(0);
      for (var i = 1; i <= 200; i++) {
        final x = i * 0.02;
        final current = noise.noise1(x);
        expect((current - previous).abs(), lessThan(0.06), reason: 'jump at x=$x');
        previous = current;
      }
    });

    test('lands exactly on the lattice value at integer coordinates', () {
      const noise = ValueNoise();
      // Smoothstep has zero slope at t=0, so a value just past an integer
      // barely moves off the lattice value there.
      final atThree = noise.noise1(3);
      expect(noise.noise1(3.001), closeTo(atThree, 1e-3));
    });

    test('is identical across two instances (determinism)', () {
      const a = ValueNoise();
      const b = ValueNoise();
      for (final x in const [0.0, 1.5, 7.25, -3.3, 42.42]) {
        expect(a.noise1(x), b.noise1(x));
      }
    });

    test('varies across the domain (not a constant)', () {
      const noise = ValueNoise();
      final samples = {for (var i = 0; i < 20; i++) noise.noise1(i.toDouble())};
      expect(samples.length, greaterThan(10));
    });
  });

  group('ValueNoise — noise2', () {
    test('is bounded to [0, 1]', () {
      const noise = ValueNoise();
      for (var y = 0; y < 20; y++) {
        for (var x = 0; x < 20; x++) {
          expect(noise.noise2(x * 0.5, y * 0.5), inInclusiveRange(0, 1));
        }
      }
    });

    test('is continuous in both axes', () {
      const noise = ValueNoise();
      var previous = noise.noise2(0, 5);
      for (var i = 1; i <= 100; i++) {
        final current = noise.noise2(i * 0.02, 5);
        expect((current - previous).abs(), lessThan(0.06));
        previous = current;
      }
      previous = noise.noise2(5, 0);
      for (var i = 1; i <= 100; i++) {
        final current = noise.noise2(5, i * 0.02);
        expect((current - previous).abs(), lessThan(0.06));
        previous = current;
      }
    });

    test('is identical across two instances (determinism)', () {
      const a = ValueNoise();
      const b = ValueNoise();
      for (final point in const [(0.0, 0.0), (1.5, 2.5), (-3.3, 7.1), (42.0, 13.0)]) {
        expect(a.noise2(point.$1, point.$2), b.noise2(point.$1, point.$2));
      }
    });

    test('varies across the plane (not a constant)', () {
      const noise = ValueNoise();
      final samples = {
        for (var y = 0; y < 8; y++)
          for (var x = 0; x < 8; x++) noise.noise2(x.toDouble(), y.toDouble()),
      };
      expect(samples.length, greaterThan(40));
    });
  });
}

/// The pinned literal of `ValueNoise().valueForSeed('leaf-7')` — captured from
/// the first green run and frozen as the seam's golden scalar.
const double _leaf7 = 0.14212382686876218;
