import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/particles/particles.dart';

const _red = Color(0xFFFF0000);
const _blue = Color(0xFF0000FF);

void main() {
  group('Particles.confetti (WI-11, D6)', () {
    test('carries the requested count and seed', () {
      const spec = Particles.confetti(count: 40, seed: 'p');
      expect(spec.count, 40);
      expect(spec.seed, 'p');
      expect(spec.kind, ParticleKind.confetti);
    });

    test('pins its defaults', () {
      const spec = Particles.confetti();
      expect(spec.count, 32);
      expect(spec.seed, 'confetti');
      expect(spec.palette.length, greaterThan(1));
      expect(spec.minSize, lessThan(spec.maxSize));
      expect(spec.fallSpeed, greaterThan(0));
      expect(spec.drift, greaterThan(0));
      expect(spec.spinSpeed, greaterThan(0));
    });

    test('accepts an overridden palette, size range, and motion', () {
      const spec = Particles.confetti(
        count: 10,
        seed: 's',
        palette: [_red, _blue],
        minSize: 3,
        maxSize: 8,
        fallSpeed: 0.5,
        drift: 0.2,
        spinSpeed: 3,
      );
      expect(spec.palette, const [_red, _blue]);
      expect(spec.minSize, 3);
      expect(spec.maxSize, 8);
      expect(spec.fallSpeed, 0.5);
      expect(spec.drift, 0.2);
      expect(spec.spinSpeed, 3);
    });
  });

  group('Particles.snow (WI-11, D6)', () {
    test('is the snow kind with its own defaults', () {
      const spec = Particles.snow();
      expect(spec.kind, ParticleKind.snow);
      expect(spec.seed, 'snow');
      expect(spec.count, 48);
      expect(spec.palette, isNotEmpty);
    });

    test('snow drifts slower and spins less than confetti by default', () {
      const snow = Particles.snow();
      const confetti = Particles.confetti();
      expect(snow.fallSpeed, lessThan(confetti.fallSpeed));
      expect(snow.spinSpeed, lessThan(confetti.spinSpeed));
    });
  });

  group('Particles.sparkle (WI-11, D6)', () {
    test('is the sparkle kind with its own defaults', () {
      const spec = Particles.sparkle();
      expect(spec.kind, ParticleKind.sparkle);
      expect(spec.seed, 'sparkle');
      expect(spec.count, 24);
    });

    test('sparkle barely falls (it twinkles in place)', () {
      const sparkle = Particles.sparkle();
      const snow = Particles.snow();
      expect(sparkle.fallSpeed, lessThan(snow.fallSpeed));
    });
  });

  group('Particles — value equality', () {
    test('equal by every field', () {
      const a = Particles.confetti(count: 12, seed: 'x');
      const b = Particles.confetti(count: 12, seed: 'x');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differs when any field differs', () {
      const base = Particles.confetti(count: 12, seed: 'x');
      expect(base, isNot(const Particles.confetti(count: 13, seed: 'x')));
      expect(base, isNot(const Particles.confetti(count: 12, seed: 'y')));
      expect(base, isNot(const Particles.snow(count: 12, seed: 'x')));
      expect(
        base,
        isNot(const Particles.confetti(count: 12, seed: 'x', palette: [_red])),
      );
    });

    test('is const-constructible (compile-time value)', () {
      const spec = Particles.confetti();
      expect(identical(spec, const Particles.confetti()), isTrue);
    });
  });

  group('Particles — toString', () {
    test('names the kind, count, and seed', () {
      expect(
        const Particles.confetti(count: 7, seed: 'k').toString(),
        contains('confetti'),
      );
      expect(const Particles.snow(count: 7, seed: 'k').toString(), contains('count: 7'));
    });
  });
}
