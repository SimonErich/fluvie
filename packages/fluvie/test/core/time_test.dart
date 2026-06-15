import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

import 'fakes/fixed_time_scope.dart';

const fps30 = FixedTimeScope(fps: 30, durationFrames: 300);
const fps60 = FixedTimeScope(fps: 60, durationFrames: 600);
const fps25 = FixedTimeScope(fps: 25, durationFrames: 100);

void main() {
  group('FrameTime', () {
    test('resolves to its exact frame count at any fps', () {
      expect(20.frames.resolveFrames(fps30), 20);
      expect(20.frames.resolveFrames(fps60), 20);
    });

    test('zero and negative counts resolve unchanged', () {
      expect(0.frames.resolveFrames(fps30), 0);
      expect((-12).frames.resolveFrames(fps60), -12);
    });
  });

  group('SecondTime', () {
    test('resolves seconds x fps', () {
      expect(2.5.seconds.resolveFrames(fps30), 75);
      expect(2.5.seconds.resolveFrames(fps60), 150);
    });

    test('rounds to the nearest frame, half away from zero', () {
      expect(0.5.seconds.resolveFrames(fps25), 13); // 12.5 -> 13
      expect(0.33.seconds.resolveFrames(fps30), 10); // 9.9 -> 10
      expect((-0.5).seconds.resolveFrames(fps25), -13); // -12.5 -> -13
    });

    test('zero and negative seconds', () {
      expect(0.seconds.resolveFrames(fps30), 0);
      expect((-2.5).seconds.resolveFrames(fps30), -75);
    });
  });

  group('MsTime', () {
    test('resolves ms / 1000 x fps', () {
      expect(500.ms.resolveFrames(fps30), 15);
      expect(500.ms.resolveFrames(fps60), 30);
    });

    test('rounds to the nearest frame', () {
      expect(333.ms.resolveFrames(fps30), 10); // 9.99 -> 10
      expect(100.ms.resolveFrames(fps25), 3); // 2.5 -> 3
      expect(999.ms.resolveFrames(fps30), 30); // 29.97 -> 30
    });

    test('zero and negative milliseconds', () {
      expect(0.ms.resolveFrames(fps60), 0);
      expect((-500).ms.resolveFrames(fps30), -15);
    });
  });

  group('RelativeTime', () {
    test('resolves fraction x durationFrames', () {
      expect(0.3.relative.resolveFrames(fps30), 90); // window 300
      expect(0.3.relative.resolveFrames(fps60), 180); // window 600
    });

    test('rounds the scaled window length', () {
      expect(0.125.relative.resolveFrames(fps25), 13); // 12.5 -> 13
    });

    test('caps at max when the uncapped value is larger', () {
      const t = Time.relative(0.5, max: Time.frames(20));
      expect(t.resolveFrames(fps30), 20); // min(150, 20)
    });

    test('ignores max when the uncapped value is smaller', () {
      const t = Time.relative(0.1, max: Time.frames(99));
      expect(t.resolveFrames(fps30), 30); // min(30, 99)
    });

    test('the cap may be any Time variant', () {
      const fromSeconds = Time.relative(1, max: Time.seconds(0.8));
      expect(fromSeconds.resolveFrames(fps30), 24); // min(300, 24)
      const fromRelative = Time.relative(0.9, max: Time.relative(0.5));
      expect(fromRelative.resolveFrames(fps30), 150); // min(270, 150)
    });

    test('a null max leaves the value uncapped', () {
      expect(1.relative.resolveFrames(fps30), 300);
    });

    test('zero and negative fractions', () {
      expect(0.relative.resolveFrames(fps30), 0);
      expect((-0.1).relative.resolveFrames(fps30), -30);
    });
  });

  group('Time.zero', () {
    test('resolves to frame zero in every scope', () {
      expect(Time.zero.resolveFrames(fps30), 0);
      expect(Time.zero.resolveFrames(fps60), 0);
    });

    test('equals an explicit zero frame count', () {
      expect(Time.zero, equals(const FrameTime(0)));
      expect(Time.zero, equals(0.frames));
    });
  });

  group('operator +', () {
    test('same-variant sums combine in their own unit', () {
      expect(10.frames + 5.frames, equals(const FrameTime(15)));
      expect(1.5.seconds + 1.seconds, equals(const SecondTime(2.5)));
      expect(200.ms + 300.ms, equals(const MsTime(500)));
      expect(0.25.relative + 0.25.relative, equals(const RelativeTime(0.5)));
    });

    test('mixed-variant sums resolve each operand, then add', () {
      final t = 1.seconds + 6.frames;
      expect(t.resolveFrames(fps30), 36);
      expect(t.resolveFrames(fps60), 66);
    });

    test('capped relatives never merge fractions', () {
      const capped = Time.relative(0.5, max: Time.frames(10));
      final sum = capped + 0.25.relative;
      // min(150, 10) + 75 -- not a merged RelativeTime(0.75, ...).
      expect(sum.resolveFrames(fps30), 85);
    });
  });

  group('operator -', () {
    test('same-variant differences combine in their own unit', () {
      expect(75.frames - 15.frames, equals(const FrameTime(60)));
      expect(2.5.seconds - 0.5.seconds, equals(const SecondTime(2)));
      expect(800.ms - 300.ms, equals(const MsTime(500)));
      expect(0.75.relative - 0.25.relative, equals(const RelativeTime(0.5)));
    });

    test('can go negative', () {
      expect(10.frames - 20.frames, equals(const FrameTime(-10)));
    });

    test('mixed-variant differences resolve each operand, then subtract', () {
      final t = 2.seconds - 10.frames;
      expect(t.resolveFrames(fps30), 50);
      expect(t.resolveFrames(fps60), 110);
    });
  });

  group('operator *', () {
    test('scales an exact frame count directly', () {
      expect(20.frames * 1.5, equals(const FrameTime(30)));
      expect(5.frames * 0.5, equals(const FrameTime(3))); // 2.5 -> 3
    });

    test('scales other variants on the resolved frames, rounding once', () {
      // 0.05 s @ 30 fps resolves to 2 (1.5 -> 2); x3 -> 6.
      // Eager unit math would give (0.15 s x 30).round() = 5.
      expect((0.05.seconds * 3).resolveFrames(fps30), 6);
    });

    test('scales composites on their resolved value', () {
      final t = (1.seconds + 1.frames) * 0.5;
      expect(t.resolveFrames(fps30), 16); // (30 + 1) x 0.5 = 15.5 -> 16
    });

    test('a capped relative scales after capping', () {
      const capped = Time.relative(0.5, max: Time.frames(10));
      expect((capped * 2).resolveFrames(fps30), 20);
    });

    test('a factor of -1 negates', () {
      expect((2.seconds * -1).resolveFrames(fps30), -60);
    });
  });

  group('value equality', () {
    test('distinct instances with the same value are equal', () {
      expect(30.frames, equals(const FrameTime(30)));
      expect(2.5.seconds, equals(const SecondTime(2.5)));
      expect(500.ms, equals(const MsTime(500)));
      expect(0.3.relative, equals(const RelativeTime(0.3)));
      expect(
        Time.relative(0.2, max: 800.ms),
        equals(const RelativeTime(0.2, max: Time.ms(800))),
      );
    });

    test('hash codes match for equal values', () {
      expect(30.frames.hashCode, const FrameTime(30).hashCode);
      expect(
        Time.relative(0.2, max: 800.ms).hashCode,
        const RelativeTime(0.2, max: Time.ms(800)).hashCode,
      );
    });

    test('different values or variants are unequal', () {
      expect(const FrameTime(30), isNot(equals(const FrameTime(31))));
      expect(const SecondTime(1), isNot(equals(const MsTime(1000))));
      expect(
        const RelativeTime(0.3),
        isNot(equals(const RelativeTime(0.3, max: Time.frames(9)))),
      );
    });

    test('const factories build the public variants', () {
      expect(const Time.frames(20), equals(const FrameTime(20)));
      expect(const Time.seconds(2.5), equals(const SecondTime(2.5)));
      expect(const Time.ms(500), equals(const MsTime(500)));
      expect(const Time.relative(0.3), equals(const RelativeTime(0.3)));
    });
  });

  group('toString', () {
    test('reads like the constructor call', () {
      expect(20.frames.toString(), 'Time.frames(20)');
      expect(2.5.seconds.toString(), 'Time.seconds(2.5)');
      expect(500.ms.toString(), 'Time.ms(500)');
      expect(0.3.relative.toString(), 'Time.relative(0.3)');
      expect(
        const Time.relative(0.2, max: Time.seconds(0.8)).toString(),
        'Time.relative(0.2, max: Time.seconds(0.8))',
      );
    });

    test('composites show their structure', () {
      expect((1.seconds + 5.frames).toString(), '(Time.seconds(1.0) + Time.frames(5))');
      expect((1.seconds - 5.frames).toString(), '(Time.seconds(1.0) - Time.frames(5))');
      expect((1.seconds * 2).toString(), '(Time.seconds(1.0) * 2)');
    });
  });

  group('composite value equality', () {
    test('mixed-unit sums of equal operands are equal', () {
      expect(1.seconds + 5.frames, 1.seconds + 5.frames);
      expect((1.seconds + 5.frames).hashCode, (1.seconds + 5.frames).hashCode);
    });

    test('mixed-unit differences of equal operands are equal', () {
      expect(1.seconds - 5.frames, 1.seconds - 5.frames);
    });

    test('scaled times of equal operands are equal', () {
      expect(1.seconds * 1.5, 1.seconds * 1.5);
      expect((1.seconds * 1.5).hashCode, (1.seconds * 1.5).hashCode);
    });

    test('different operands or factors stay unequal', () {
      expect(1.seconds + 5.frames, isNot(2.seconds + 5.frames));
      expect(1.seconds + 5.frames, isNot(1.seconds - 5.frames));
      expect(1.seconds * 1.5, isNot(1.seconds * 2));
    });
  });
}
