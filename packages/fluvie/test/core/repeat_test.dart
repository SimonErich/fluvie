import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/repeat.dart';
import 'package:fluvie/src/core/time.dart';

void main() {
  group('Repeat.times', () {
    test('stores count, yoyo, and gap', () {
      const repeat = Repeat.times(3, yoyo: true, gap: Time.frames(6));
      expect(repeat.count, 3);
      expect(repeat.yoyo, isTrue);
      expect(repeat.gap, const Time.frames(6));
    });

    test('defaults: yoyo false, gap zero', () {
      const repeat = Repeat.times(2);
      expect(repeat.yoyo, isFalse);
      expect(repeat.gap, Time.zero);
    });

    test('isForever is false', () {
      expect(const Repeat.times(1).isForever, isFalse);
    });

    test('count < 1 asserts', () {
      expect(() => Repeat.times(0), throwsA(isA<AssertionError>()));
      expect(() => Repeat.times(-2), throwsA(isA<AssertionError>()));
    });
  });

  group('Repeat.forever', () {
    test('isForever is true and count is null', () {
      const repeat = Repeat.forever();
      expect(repeat.isForever, isTrue);
      expect(repeat.count, isNull);
    });

    test('gap is fixed at zero', () {
      expect(const Repeat.forever().gap, Time.zero);
      expect(const Repeat.forever(yoyo: true).gap, Time.zero);
    });

    test('carries yoyo', () {
      expect(const Repeat.forever(yoyo: true).yoyo, isTrue);
      expect(const Repeat.forever().yoyo, isFalse);
    });
  });

  group('value equality', () {
    test('equal times variants are equal', () {
      expect(
        const Repeat.times(2, yoyo: true, gap: Time.frames(3)),
        const Repeat.times(2, yoyo: true, gap: Time.frames(3)),
      );
      expect(
        const Repeat.times(2, yoyo: true, gap: Time.frames(3)).hashCode,
        const Repeat.times(2, yoyo: true, gap: Time.frames(3)).hashCode,
      );
    });

    test('differing fields are unequal', () {
      expect(const Repeat.times(2), isNot(const Repeat.times(3)));
      expect(const Repeat.times(2), isNot(const Repeat.times(2, yoyo: true)));
      expect(
        const Repeat.times(2),
        isNot(const Repeat.times(2, gap: Time.frames(1))),
      );
    });

    test('forever and times are never equal', () {
      expect(const Repeat.forever(), isNot(const Repeat.times(1)));
      expect(const Repeat.forever(), const Repeat.forever());
    });
  });

  group('toString', () {
    test('is stable for both variants', () {
      expect(
        const Repeat.times(2, yoyo: true, gap: Time.frames(3)).toString(),
        'Repeat.times(2, yoyo: true, gap: Time.frames(3))',
      );
      expect(const Repeat.times(2).toString(), 'Repeat.times(2)');
      expect(const Repeat.forever().toString(), 'Repeat.forever()');
      expect(const Repeat.forever(yoyo: true).toString(), 'Repeat.forever(yoyo: true)');
    });
  });
}
