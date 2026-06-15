import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

import 'fakes/fixed_time_scope.dart';

const fps30 = FixedTimeScope(fps: 30, durationFrames: 300);
const fps60 = FixedTimeScope(fps: 60, durationFrames: 600);

void main() {
  group('construction', () {
    test('.to() builds a range from two Times', () {
      final range = 3.seconds.to(8.seconds);
      expect(range.start, equals(const SecondTime(3)));
      expect(range.end, equals(const SecondTime(8)));
    });

    test('the constructor takes start and end positionally', () {
      const range = TimeRange(Time.frames(10), Time.frames(40));
      expect(range.resolveFrames(fps30), (start: 10, end: 40));
    });
  });

  group('resolveFrames', () {
    test('resolves both endpoints against the scope', () {
      final range = 3.seconds.to(8.seconds);
      expect(range.resolveFrames(fps30), (start: 90, end: 240));
      expect(range.resolveFrames(fps60), (start: 180, end: 480));
    });

    test('relative endpoints resolve against the scope window', () {
      final range = 0.25.relative.to(0.75.relative);
      expect(range.resolveFrames(fps30), (start: 75, end: 225));
      expect(range.resolveFrames(fps60), (start: 150, end: 450));
    });

    test('throws on an inverted range, naming both endpoints', () {
      final range = 8.seconds.to(3.seconds);
      expect(
        () => range.resolveFrames(fps30),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('Time.seconds(8.0)'),
              contains('Time.seconds(3.0)'),
              contains('240'),
              contains('90'),
            ),
          ),
        ),
      );
    });

    test('mixed units can invert at one fps and not another', () {
      final range = 1.seconds.to(40.frames);
      expect(range.resolveFrames(fps30), (start: 30, end: 40));
      expect(() => range.resolveFrames(fps60), throwsArgumentError);
    });
  });

  group('durationFrames', () {
    test('is the resolved end minus the resolved start', () {
      final range = 3.seconds.to(8.seconds);
      expect(range.durationFrames(fps30), 150);
      expect(range.durationFrames(fps60), 300);
    });

    test('throws on an inverted range', () {
      final range = 8.seconds.to(3.seconds);
      expect(() => range.durationFrames(fps30), throwsArgumentError);
    });
  });

  group('containsFrame', () {
    test('start is inclusive, end is exclusive', () {
      final range = 3.seconds.to(8.seconds); // 90..240 @ 30 fps
      expect(range.containsFrame(89, fps30), isFalse);
      expect(range.containsFrame(90, fps30), isTrue);
      expect(range.containsFrame(239, fps30), isTrue);
      expect(range.containsFrame(240, fps30), isFalse);
    });

    test('a zero-length range is valid and contains no frame', () {
      final range = 2.seconds.to(2.seconds);
      expect(range.durationFrames(fps30), 0);
      expect(range.containsFrame(59, fps30), isFalse);
      expect(range.containsFrame(60, fps30), isFalse);
      expect(range.containsFrame(61, fps30), isFalse);
    });
  });

  group('resolveClamped', () {
    test('clamps both endpoints into [min, max]', () {
      final range = 3.seconds.to(8.seconds); // 90..240 @ 30 fps
      expect(range.resolveClamped(fps30, min: 100, max: 200), (start: 100, end: 200));
    });

    test('leaves a fully inside range untouched', () {
      final range = 3.seconds.to(8.seconds);
      expect(range.resolveClamped(fps30, min: 0, max: 300), (start: 90, end: 240));
    });

    test('collapses a range entirely outside the bounds', () {
      final range = 3.seconds.to(8.seconds); // 90..240 @ 30 fps
      expect(range.resolveClamped(fps30, min: 250, max: 280), (start: 250, end: 250));
      expect(range.resolveClamped(fps30, min: 0, max: 50), (start: 50, end: 50));
    });

    test('still rejects an inverted range', () {
      final range = 8.seconds.to(3.seconds);
      expect(() => range.resolveClamped(fps30, min: 0, max: 300), throwsArgumentError);
    });

    test('rejects min greater than max', () {
      final range = 3.seconds.to(8.seconds);
      expect(() => range.resolveClamped(fps30, min: 10, max: 5), throwsArgumentError);
    });
  });
}
