import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

void main() {
  group('TimeNum', () {
    test('frames builds a FrameTime', () {
      expect(20.frames, isA<FrameTime>().having((t) => t.frames, 'frames', 20));
    });

    test('an integral double is a valid frame count', () {
      const double whole = 2;
      expect(whole.frames, equals(const FrameTime(2)));
    });

    test('a fractional frame count asserts', () {
      expect(() => 2.5.frames, throwsA(isA<AssertionError>()));
    });

    test('seconds builds a SecondTime', () {
      expect(2.5.seconds, isA<SecondTime>().having((t) => t.seconds, 'seconds', 2.5));
    });

    test('an int receiver becomes double seconds', () {
      expect(2.seconds, isA<SecondTime>().having((t) => t.seconds, 'seconds', 2));
    });

    test('ms builds an MsTime', () {
      expect(500.ms, isA<MsTime>().having((t) => t.milliseconds, 'milliseconds', 500));
    });

    test('a fractional millisecond count asserts', () {
      expect(() => 0.5.ms, throwsA(isA<AssertionError>()));
    });

    test('relative builds an uncapped RelativeTime', () {
      expect(
        0.3.relative,
        isA<RelativeTime>()
            .having((t) => t.fraction, 'fraction', 0.3)
            .having((t) => t.max, 'max', isNull),
      );
    });

    test('negative receivers keep their sign', () {
      expect((-5).frames, equals(const FrameTime(-5)));
      expect((-0.5).seconds, equals(const SecondTime(-0.5)));
      expect((-250).ms, equals(const MsTime(-250)));
      expect((-0.1).relative, equals(const RelativeTime(-0.1)));
    });
  });
}
