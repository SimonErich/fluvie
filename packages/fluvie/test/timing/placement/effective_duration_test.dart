import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/spring_solver.dart';
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/core/timing.dart';
import 'package:fluvie/src/timing/placement/effective_duration.dart';
import 'package:fluvie/src/timing/placement/window_resolver.dart';
import 'package:fluvie/src/timing/plan/animation_plan.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

void main() {
  const merged = Defaults.package;
  // A 10s scene @30fps: frames 0..300.
  const scene = TimeScopeData(fps: 30, startFrame: 0, durationFrames: 300);

  group('effectiveDurationFrames', () {
    test('a Tween resolves its duration at the scope fps', () {
      const plan = AnimationPlan(
        phase: AnimationPhase.enter,
        timing: Tween(Time.seconds(0.5)),
      );
      expect(effectiveDurationFrames(plan, merged, scene), 15);
    });

    test('a Spring uses the solver settle frames (cross-check)', () {
      const plan = AnimationPlan(phase: AnimationPhase.enter, timing: Spring.snappy);
      expect(
        effectiveDurationFrames(plan, merged, scene),
        SpringSolver(Spring.snappy).settleFrames(30),
      );
    });

    test('a bouncy spring settles later than a stiff one', () {
      const bouncy = AnimationPlan(phase: AnimationPhase.enter, timing: Spring.bouncy);
      const stiff = AnimationPlan(phase: AnimationPhase.enter, timing: Spring.stiff);
      expect(
        effectiveDurationFrames(bouncy, merged, scene),
        greaterThan(effectiveDurationFrames(stiff, merged, scene)),
      );
    });

    test('a zero-damping spring surfaces the solver ArgumentError', () {
      const plan = AnimationPlan(
        phase: AnimationPhase.enter,
        timing: Spring(damping: 0),
      );
      expect(() => effectiveDurationFrames(plan, merged, scene), throwsArgumentError);
    });

    test('no timing falls back to the merged default duration', () {
      const plan = AnimationPlan(phase: AnimationPhase.enter);
      const withFixed = Defaults(duration: Time.seconds(0.4), ease: Ease.smooth);
      expect(effectiveDurationFrames(plan, withFixed, scene), 12);
    });

    test('package default is 20% of a 2s window: 12 frames @30fps', () {
      const plan = AnimationPlan(phase: AnimationPhase.enter);
      const window = TimeScopeData(fps: 30, startFrame: 0, durationFrames: 60);
      expect(effectiveDurationFrames(plan, merged, window), 12);
    });

    test('package default caps at 0.8s on a 10s window: 24 frames @30fps', () {
      const plan = AnimationPlan(phase: AnimationPhase.enter);
      expect(effectiveDurationFrames(plan, merged, scene), 24);
    });

    test('the default measures the element window, not the scene', () {
      const plan = AnimationPlan(phase: AnimationPhase.enter);
      final window = elementScopeFor(3.seconds.to(5.seconds), scene);
      // 20% of the 2s window (12), not 20% of the 10s scene capped (24).
      expect(effectiveDurationFrames(plan, merged, window), 12);
    });
  });

  group('mergeDefaultsChain (D14)', () {
    test('element wins over scene, video, and package', () {
      final mergedChain = mergeDefaultsChain(
        element: const Defaults(duration: Time.seconds(0.1)),
        scene: const Defaults(duration: Time.seconds(0.2)),
        video: const Defaults(duration: Time.seconds(0.3)),
      );
      expect(mergedChain.duration, const SecondTime(0.1));
    });

    test('scene wins over video when the element is unset', () {
      final mergedChain = mergeDefaultsChain(
        scene: const Defaults(duration: Time.seconds(0.2)),
        video: const Defaults(duration: Time.seconds(0.3)),
      );
      expect(mergedChain.duration, const SecondTime(0.2));
    });

    test('video wins over the package default; other fields cascade independently', () {
      final mergedChain = mergeDefaultsChain(
        scene: const Defaults(ease: Ease.snappy),
        video: const Defaults(duration: Time.seconds(0.3)),
      );
      expect(mergedChain.duration, const SecondTime(0.3));
      expect(mergedChain.ease, Ease.snappy);
    });

    test('all levels unset: the package defaults fill every field', () {
      final mergedChain = mergeDefaultsChain();
      expect(mergedChain.duration, Defaults.package.duration);
      expect(mergedChain.ease, Ease.smooth);
      expect(mergedChain.stagger, isNull);
    });
  });

  group('mergeDefaultsChain — the FluvieTheme.motion layer (WI-4, D-MotionCascade)', () {
    test('the theme layer wins over the package default', () {
      final mergedChain = mergeDefaultsChain(
        theme: const Defaults(duration: Time.seconds(0.5), ease: Ease.out),
      );
      expect(mergedChain.duration, const SecondTime(0.5));
      expect(mergedChain.ease, Ease.out);
    });

    test('video beats the theme (the precedence pin)', () {
      final mergedChain = mergeDefaultsChain(
        video: const Defaults(duration: Time.seconds(0.3)),
        theme: const Defaults(duration: Time.seconds(0.5)),
      );
      expect(mergedChain.duration, const SecondTime(0.3));
    });

    test('scene beats the theme', () {
      final mergedChain = mergeDefaultsChain(
        scene: const Defaults(ease: Ease.snappy),
        theme: const Defaults(ease: Ease.out),
      );
      expect(mergedChain.ease, Ease.snappy);
    });

    test('element beats the theme', () {
      final mergedChain = mergeDefaultsChain(
        element: const Defaults(duration: Time.seconds(0.1)),
        theme: const Defaults(duration: Time.seconds(0.5)),
      );
      expect(mergedChain.duration, const SecondTime(0.1));
    });

    test('the full precedence: element > scene > video > theme > package', () {
      // Each layer pins a different field, so the result reads one from each.
      final mergedChain = mergeDefaultsChain(
        element: const Defaults(duration: Time.seconds(0.1)),
        scene: const Defaults(ease: Ease.snappy),
        video: const Defaults(stagger: Stagger.each(Time.seconds(0.05))),
        theme: const Defaults(duration: Time.seconds(0.9), ease: Ease.out),
      );
      expect(mergedChain.duration, const SecondTime(0.1)); // element
      expect(mergedChain.ease, Ease.snappy); // scene
      expect(mergedChain.stagger, const Stagger.each(SecondTime(0.05))); // video
    });

    test('the theme fills a field no higher layer sets', () {
      final mergedChain = mergeDefaultsChain(
        video: const Defaults(duration: Time.seconds(0.3)),
        theme: const Defaults(ease: Ease.out),
      );
      expect(mergedChain.duration, const SecondTime(0.3)); // video
      expect(mergedChain.ease, Ease.out); // theme fills the unset ease
    });
  });
}
