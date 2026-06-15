import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/timing/placement/scene_frame_resolver.dart';

void main() {
  group('resolveSceneDurationFrames', () {
    test('absolute durations resolve at the given fps', () {
      expect(resolveSceneDurationFrames(90.frames, 30, 'a'), 90);
      expect(resolveSceneDurationFrames(2.seconds, 30, 'a'), 60);
      expect(resolveSceneDurationFrames(2.seconds, 60, 'a'), 120);
      expect(resolveSceneDurationFrames(500.ms, 30, 'a'), 15);
    });

    test('composite absolute durations resolve too', () {
      expect(resolveSceneDurationFrames(1.seconds + 15.frames, 30, 'a'), 45);
    });

    test('a relative duration throws a FluvieTimingError naming the scene (D13)', () {
      expect(
        () => resolveSceneDurationFrames(0.5.relative, 30, 'loop'),
        throwsA(isA<FluvieTimingError>().having((e) => e.message, 'message', contains("'loop'"))),
      );
    });

    test('a composite hiding a relative component throws the same way', () {
      expect(
        () => resolveSceneDurationFrames(1.seconds + 0.1.relative, 30, 'sum'),
        throwsA(isA<FluvieTimingError>().having((e) => e.message, 'message', contains("'sum'"))),
      );
    });

    test('the guard message is byte-identical to the resolver wording (D27)', () {
      expect(
        () => resolveSceneDurationFrames(0.5.relative, 30, 'intro'),
        throwsA(
          isA<FluvieTimingError>().having(
            (e) => e.message,
            'message',
            "The duration of scene 'intro' cannot be relative: scene "
                'durations define the video length, so a relative duration would be '
                'a fraction of itself. Use frames, seconds, or ms for scene durations.',
          ),
        ),
      );
    });
  });
}
