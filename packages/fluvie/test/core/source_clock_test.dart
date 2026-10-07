import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/src/core/time.dart';

void main() {
  test('source trim units retain fractional FPS and presentation-clock semantics', () {
    final cases = <(Time, int, double, double)>[
      (10.frames, 10, 10, .4),
      (1.seconds, 30, 29.97, 1),
      (500.ms, 15, 14.985, .5),
      (.5.relative, 150, 150, 5.85),
      (const Time.relative(.5, max: Time.seconds(1)), 30, 29.97, 1),
      (1.seconds + 10.frames, 40, 39.97, 1.4),
      (2.seconds - 500.ms, 45, 44.955, 1.5),
      (1.seconds * 1.5, 45, 44.955, 1.5),
    ];
    for (final (time, frames, offset, seconds) in cases) {
      expect(resolveSourceTimeFrames(time, fps: 29.97, durationFrames: 300), frames);
      expect(resolveSourceTimeOffset(time, fps: 29.97, durationFrames: 300), closeTo(offset, 1e-9));
      expect(
        resolveSourceTimeSeconds(
          time,
          fps: 29.97,
          durationFrames: 300,
          durationSeconds: 11.7,
          frameTime: (frame) => frame * .04,
        ),
        closeTo(seconds, 1e-9),
      );
    }
    expect(
      resolveSourceTimeSeconds(10.frames, fps: 29.97, durationFrames: 300),
      closeTo(10 / 29.97, 1e-9),
    );
    expect(
      resolveSourceTimeSeconds(.5.relative, fps: 29.97, durationFrames: 300),
      closeTo(150 / 29.97, 1e-9),
    );
  });
  test('composition callbacks cannot silently become imported source trims', () {
    final computed = ComputedTime((scope) => scope.durationFrames);
    expect(
      () => resolveSourceTimeFrames(computed, fps: 30, durationFrames: 100),
      throwsArgumentError,
    );
    expect(
      () => resolveSourceTimeOffset(computed, fps: 30, durationFrames: 100),
      throwsArgumentError,
    );
    expect(
      () => resolveSourceTimeSeconds(computed, fps: 30, durationFrames: 100),
      throwsArgumentError,
    );
  });
}
