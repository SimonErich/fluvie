import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/core/spring_solver.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/core/timing.dart';
import 'package:fluvie/src/timing/placement/placement.dart';
import 'package:fluvie/src/timing/placement/window_resolver.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

void main() {
  // A 10s window @30fps starting 5s into the video: frames 150..450.
  const w0 = 150;
  const w1 = 450;

  ({int start, int end}) place(
    AnimationPhase phase, {
    int duration = 24,
    int delay = 0,
    int windowStart = w0,
    int windowEnd = w1,
  }) => placeAuto(
    phase: phase,
    windowStart: windowStart,
    windowEnd: windowEnd,
    durationFrames: duration,
    delayFrames: delay,
  );

  group('placeAuto', () {
    test('enter with zero delay starts at the window start', () {
      expect(place(AnimationPhase.enter), (start: 150, end: 174));
    });

    test('enter is pushed back by its delay', () {
      expect(place(AnimationPhase.enter, delay: 15), (start: 165, end: 189));
    });

    test('exit with zero delay is end-anchored at the window end', () {
      expect(place(AnimationPhase.exit), (start: 426, end: 450));
    });

    test('exit delay pulls the whole span earlier: end = windowEnd - delay (D3)', () {
      expect(place(AnimationPhase.exit, delay: 15), (start: 411, end: 435));
    });

    test('during spans the window regardless of duration', () {
      expect(place(AnimationPhase.during), (start: 150, end: 450));
    });

    test('during with a delay starts late but still ends at the window end', () {
      expect(place(AnimationPhase.during, delay: 15), (start: 165, end: 450));
    });

    test('a zero-duration animation is a zero-length span at its edge', () {
      expect(place(AnimationPhase.enter, duration: 0), (start: 150, end: 150));
      expect(place(AnimationPhase.exit, duration: 0), (start: 450, end: 450));
    });

    test('a spring span is its settle time: enter from the start, exit into the end', () {
      final settle = SpringSolver(Spring.snappy).settleFrames(30);
      expect(
        place(AnimationPhase.enter, duration: settle),
        (start: 150, end: 150 + settle),
      );
      expect(
        place(AnimationPhase.exit, duration: settle),
        (start: 450 - settle, end: 450),
      );
    });

    test('a relative delay resolves against the element window before placement', () {
      // A 4s element window of a 10s scene: frames 210..330; 0.1.relative = 12.
      const scene = TimeScopeData(fps: 30, startFrame: 150, durationFrames: 300);
      final window = elementScopeFor(2.seconds.to(6.seconds), scene);
      final delay = 0.1.relative.resolveFrames(window);
      expect(delay, 12);
      expect(
        place(
          AnimationPhase.enter,
          delay: delay,
          windowStart: window.startFrame,
          windowEnd: window.endFrame,
        ),
        (start: 222, end: 246),
      );
    });

    test('enter and exit on one window meet without overlap when it is long enough', () {
      final enter = place(AnimationPhase.enter, duration: 30);
      final exit = place(AnimationPhase.exit, duration: 30);
      expect(enter.end, lessThanOrEqualTo(exit.start));
      expect(enter, (start: 150, end: 180));
      expect(exit, (start: 420, end: 450));
    });

    test('placement is raw math: a too-long duration overhangs, no clamping here (D9)', () {
      final enter = place(AnimationPhase.enter, duration: 400);
      final exit = place(AnimationPhase.exit, duration: 400);
      expect(enter, (start: 150, end: 550)); // overhangs w1 = 450
      expect(exit, (start: 50, end: 450)); // starts before w0 = 150
    });
  });
}
