import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/runtime/animation_plan_adapter.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/keyframe.dart';
import 'package:fluvie/src/core/repeat.dart';
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/timing.dart';
import 'package:fluvie/src/core/trigger.dart';

void main() {
  group('toAnimationPlan', () {
    test('spring wins over duration and ease', () {
      final animation = Animation.from(
        const Keyframe(opacity: 0),
        spring: Spring.snappy,
        duration: const Time.frames(20),
        ease: Ease.linear,
      );
      expect(toAnimationPlan(animation).timing, Spring.snappy);
    });

    test('duration-only becomes a Tween with Ease.smooth', () {
      final animation = Animation.from(const Keyframe(opacity: 0), duration: const Time.frames(20));
      expect(toAnimationPlan(animation).timing, const Tween(Time.frames(20)));
    });

    test('duration with an explicit ease becomes a Tween with that ease', () {
      final animation = Animation.from(
        const Keyframe(opacity: 0),
        duration: const Time.frames(20),
        ease: Ease.linear,
      );
      expect(toAnimationPlan(animation).timing, const Tween(Time.frames(20), ease: Ease.linear));
    });

    test('ease-only leaves timing null so the duration inherits (D3/D14)', () {
      final animation = Animation.from(const Keyframe(opacity: 0), ease: Ease.linear);
      expect(toAnimationPlan(animation).timing, isNull);
    });

    test('all declared fields are carried verbatim', () {
      const stagger = Stagger.each(Time.ms(80));
      const repeat = Repeat.times(3, yoyo: true);
      final animation = Animation.to(
        const Keyframe(opacity: 0),
        delay: const Time.frames(5),
        at: Trigger.sceneEnd,
        stagger: stagger,
        repeat: repeat,
        label: 'outro',
      );
      final plan = toAnimationPlan(animation);
      expect(plan.phase, AnimationPhase.exit);
      expect(plan.delay, const Time.frames(5));
      expect(plan.at, Trigger.sceneEnd);
      expect(plan.stagger, same(stagger));
      expect(plan.repeat, repeat);
      expect(plan.label, 'outro');
    });
  });

  group('effectiveCurve', () {
    test('an explicit ease wins even when timing stays null', () {
      final animation = Animation.from(const Keyframe(opacity: 0), ease: Ease.snappy);
      const merged = Defaults(ease: Ease.gentle);
      expect(effectiveCurve(animation, merged), Ease.snappy);
    });

    test('falls back to the merged Defaults ease', () {
      final animation = Animation.from(const Keyframe(opacity: 0));
      const merged = Defaults(ease: Ease.gentle);
      expect(effectiveCurve(animation, merged), Ease.gentle);
    });

    test('falls back to Ease.smooth when even the merged ease is unset', () {
      final animation = Animation.from(const Keyframe(opacity: 0));
      expect(effectiveCurve(animation, const Defaults()), Ease.smooth);
    });
  });
}
