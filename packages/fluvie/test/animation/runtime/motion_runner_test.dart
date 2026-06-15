import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/runtime/motion_runner.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/repeat.dart';
import 'package:fluvie/src/core/spring_solver.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/timing.dart';
import 'package:fluvie/src/timing/resolver/trigger_resolver.dart';

void main() {
  const fps = 30;

  double run(
    int frame, {
    ResolvedSpan span = const ResolvedSpan(0, 10),
    Spring? spring,
    Repeat? repeat,
    int cycleFrames = 0,
    int gapFrames = 0,
  }) => MotionRunner.progress(
    frame: frame,
    span: span,
    ease: Ease.linear,
    spring: spring,
    fps: fps,
    repeat: repeat,
    cycleFrames: cycleFrames,
    gapFrames: gapFrames,
  );

  group('clamped tween progress (D6)', () {
    test('a linear 10-frame span maps 0/5/10 to 0/0.5/1', () {
      expect(run(0), 0);
      expect(run(5), 0.5);
      expect(run(10), 1);
    });

    test('before the span start progress holds at 0', () {
      expect(run(-1), 0);
      expect(run(3, span: const ResolvedSpan(5, 15)), 0);
    });

    test('at and after the span end progress is exactly 1', () {
      expect(run(10), 1.0);
      expect(run(999), 1.0);
    });

    test('a zero-length span is already complete', () {
      expect(run(7, span: const ResolvedSpan(7, 7)), 1);
      expect(run(8, span: const ResolvedSpan(7, 7)), 1);
    });

    test('a non-zero span start offsets the linear ramp', () {
      expect(run(105, span: const ResolvedSpan(100, 110)), 0.5);
    });

    test('a non-linear ease matches curve.transform of linear t', () {
      final shaped = MotionRunner.progress(
        frame: 5,
        span: const ResolvedSpan(0, 10),
        ease: Ease.snappy,
        fps: fps,
      );
      expect(shaped, Ease.snappy.transform(0.5));
    });
  });

  group('spring shaping (D6, §27.4)', () {
    final solver = SpringSolver(Spring.bouncy);
    final settle = solver.settleFrames(fps);
    final span = ResolvedSpan(0, settle);

    test('mid-flight progress overshoots past 1 (un-clamped)', () {
      final values = [
        for (var f = 1; f < settle; f++) run(f, span: span, spring: Spring.bouncy),
      ];
      expect(values.any((v) => v > 1), isTrue);
    });

    test('progress is exactly 1.0 at settleFrames and held after', () {
      expect(run(settle, span: span, spring: Spring.bouncy), 1.0);
      for (var f = settle; f < settle + 10; f++) {
        expect(run(f, span: span, spring: Spring.bouncy), 1.0);
      }
    });

    test('cross-checks SpringSolver at exact frames', () {
      for (final f in [3, 7, 11]) {
        expect(
          run(f, span: span, spring: Spring.bouncy),
          1 - solver.value(f / fps),
        );
      }
    });

    test('progress starts at 0 (unit displacement)', () {
      expect(run(0, span: span, spring: Spring.bouncy), 0);
    });
  });

  group('repeat (D12)', () {
    const during = ResolvedSpan(0, 40);

    test('no repeat means a single pass over the whole span', () {
      expect(run(20, span: during), 0.5);
      expect(run(40, span: during), 1);
    });

    test('forever loops with cycle length cycleFrames', () {
      const repeat = Repeat.forever();
      expect(run(2, span: during, repeat: repeat, cycleFrames: 10), closeTo(0.2, 1e-12));
      expect(run(12, span: during, repeat: repeat, cycleFrames: 10), closeTo(0.2, 1e-12));
      expect(run(32, span: during, repeat: repeat, cycleFrames: 10), closeTo(0.2, 1e-12));
    });

    test('forever yoyo reverses the linear position of odd cycles', () {
      const repeat = Repeat.forever(yoyo: true);
      expect(run(12, span: during, repeat: repeat, cycleFrames: 10), closeTo(0.8, 1e-12));
      expect(run(15, span: during, repeat: repeat, cycleFrames: 10), closeTo(0.5, 1e-12));
    });

    test('yoyo reversal happens before curve shaping', () {
      final shaped = MotionRunner.progress(
        frame: 12,
        span: during,
        ease: Ease.snappy,
        fps: fps,
        repeat: const Repeat.forever(yoyo: true),
        cycleFrames: 10,
      );
      expect(shaped, Ease.snappy.transform(0.8));
    });

    test('cycle boundaries are exact', () {
      expect(run(10, span: during, repeat: const Repeat.forever(), cycleFrames: 10), 0);
      expect(
        run(10, span: during, repeat: const Repeat.forever(yoyo: true), cycleFrames: 10),
        1,
      );
    });

    test('times(n) holds the final endpoint after n cycles', () {
      const repeat = Repeat.times(2);
      expect(run(25, span: during, repeat: repeat, cycleFrames: 10), 1);
      expect(run(39, span: during, repeat: repeat, cycleFrames: 10), 1);
    });

    test('times(2) yoyo holds at the second cycle endpoint (0)', () {
      const repeat = Repeat.times(2, yoyo: true);
      expect(run(25, span: during, repeat: repeat, cycleFrames: 10), 0);
      expect(run(39, span: during, repeat: repeat, cycleFrames: 10), 0);
    });

    test('gap frames hold the just-reached endpoint', () {
      const repeat = Repeat.times(2, yoyo: true, gap: Time.frames(5));
      // Cycle 0 runs frames 0..10, gap holds 1.0 through frame 14.
      expect(run(12, span: during, repeat: repeat, cycleFrames: 10, gapFrames: 5), 1);
      // Cycle 1 (reversed) runs 15..25, its gap holds 0.0.
      expect(run(27, span: during, repeat: repeat, cycleFrames: 10, gapFrames: 5), 0);
      expect(run(20, span: during, repeat: repeat, cycleFrames: 10, gapFrames: 5), 0.5);
    });

    test('a repeated spring holds exactly 1.0 in gaps and at the final hold', () {
      final settle = SpringSolver(Spring.snappy).settleFrames(fps);
      final span = ResolvedSpan(0, settle * 3);
      const repeat = Repeat.times(2, gap: Time.frames(4));
      final inGap = run(
        settle + 1,
        span: span,
        spring: Spring.snappy,
        repeat: repeat,
        cycleFrames: settle,
        gapFrames: 4,
      );
      expect(inGap, 1.0);
      final afterAllCycles = run(
        2 * settle + 4 + 5,
        span: span,
        spring: Spring.snappy,
        repeat: repeat,
        cycleFrames: settle,
        gapFrames: 4,
      );
      expect(afterAllCycles, 1.0);
    });
  });

  group('determinism', () {
    test('two identical calls return byte-identical values', () {
      for (final frame in [0, 3, 7, 12, 25, 40]) {
        final a = run(frame, span: const ResolvedSpan(0, 40), spring: Spring.bouncy);
        final b = run(frame, span: const ResolvedSpan(0, 40), spring: Spring.bouncy);
        expect(a, b);
      }
    });
  });
}
