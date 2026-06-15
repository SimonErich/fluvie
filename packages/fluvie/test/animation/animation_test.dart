import 'package:flutter/widgets.dart' show Path;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/animation_effect.dart';
import 'package:fluvie/src/animation/effects/keyframe_effect.dart';
import 'package:fluvie/src/animation/effects/multi_keyframe_effect.dart';
import 'package:fluvie/src/animation/effects/path_effect.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/keyframe.dart';
import 'package:fluvie/src/core/repeat.dart';
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/timing.dart';
import 'package:fluvie/src/core/trigger.dart';

import 'fakes/fake_pixel_effect.dart';

void main() {
  group('phase inference (D4)', () {
    test('from infers enter, to infers exit', () {
      expect(Animation.from(const Keyframe(opacity: 0)).phase, AnimationPhase.enter);
      expect(Animation.to(const Keyframe(opacity: 0)).phase, AnimationPhase.exit);
    });

    test('fromTo, keyframes, along, and custom default to enter', () {
      expect(
        Animation.fromTo(const Keyframe(x: -1), const Keyframe(x: 1)).phase,
        AnimationPhase.enter,
      );
      expect(
        Animation.keyframes(const [Keyframe(y: 0), Keyframe(y: 1)]).phase,
        AnimationPhase.enter,
      );
      expect(Animation.along(Path()..lineTo(10, 0)).phase, AnimationPhase.enter);
      expect(const Animation.custom(FakePixelEffect()).phase, AnimationPhase.enter);
    });

    test('phase: overrides the inferred default', () {
      expect(
        Animation.from(const Keyframe(opacity: 0), phase: AnimationPhase.during).phase,
        AnimationPhase.during,
      );
      expect(
        Animation.fromTo(
          const Keyframe(x: -1),
          const Keyframe(x: 1),
          phase: AnimationPhase.exit,
        ).phase,
        AnimationPhase.exit,
      );
      expect(
        const Animation.custom(FakePixelEffect(), phase: AnimationPhase.during).phase,
        AnimationPhase.during,
      );
    });
  });

  group('timing getter (D3, §9)', () {
    test('spring wins over duration and ease', () {
      final animation = Animation.from(
        const Keyframe(scale: 0),
        duration: const Time.seconds(1),
        ease: Ease.snappy,
        spring: Spring.bouncy,
      );
      expect(animation.timing, Spring.bouncy);
    });

    test('duration becomes a Tween with the explicit ease', () {
      final animation = Animation.from(
        const Keyframe(opacity: 0),
        duration: const Time.frames(20),
        ease: Ease.snappy,
      );
      expect(animation.timing, const Tween(Time.frames(20), ease: Ease.snappy));
    });

    test('duration without ease falls back to Ease.smooth', () {
      final animation = Animation.from(
        const Keyframe(opacity: 0),
        duration: const Time.frames(20),
      );
      expect(animation.timing, const Tween(Time.frames(20)));
    });

    test('all-null timing fields leave timing null (inherit Defaults)', () {
      final animation = Animation.from(const Keyframe(opacity: 0));
      expect(animation.timing, isNull);
      expect(animation.duration, isNull);
      expect(animation.ease, isNull);
      expect(animation.spring, isNull);
    });

    test('ease alone keeps timing null — duration still inherits', () {
      final animation = Animation.from(const Keyframe(opacity: 0), ease: Ease.snappy);
      expect(animation.timing, isNull);
      expect(animation.ease, Ease.snappy);
    });
  });

  group('common defaults', () {
    test('delay zero, at auto, null stagger/repeat/label', () {
      final animation = Animation.from(const Keyframe(opacity: 0));
      expect(animation.delay, Time.zero);
      expect(animation.at, Trigger.auto);
      expect(animation.stagger, isNull);
      expect(animation.repeat, isNull);
      expect(animation.label, isNull);
    });

    test('every common field is carried verbatim', () {
      final animation = Animation.to(
        const Keyframe(opacity: 0),
        delay: const Time.frames(4),
        at: Trigger.sceneEnd,
        stagger: const Stagger.each(Time.frames(2)),
        repeat: const Repeat.times(2),
        label: 'farewell',
      );
      expect(animation.delay, const Time.frames(4));
      expect(animation.at, Trigger.sceneEnd);
      expect(animation.stagger, const Stagger.each(Time.frames(2)));
      expect(animation.repeat, const Repeat.times(2));
      expect(animation.label, 'farewell');
    });
  });

  group('effects (D2/D17)', () {
    test('from builds a KeyframeEffect from the keyframe to natural', () {
      final animation = Animation.from(const Keyframe(opacity: 0, y: 1));
      final effect = animation.effect as KeyframeEffect;
      expect(effect.from, const Keyframe(opacity: 0, y: 1));
      expect(effect.to, Keyframe.natural);
    });

    test('to builds a KeyframeEffect from natural to the keyframe', () {
      final animation = Animation.to(const Keyframe(opacity: 0));
      final effect = animation.effect as KeyframeEffect;
      expect(effect.from, Keyframe.natural);
      expect(effect.to, const Keyframe(opacity: 0));
    });

    test('fromTo carries both endpoints', () {
      final animation = Animation.fromTo(const Keyframe(x: -1), const Keyframe(x: 1));
      final effect = animation.effect as KeyframeEffect;
      expect(effect.from, const Keyframe(x: -1));
      expect(effect.to, const Keyframe(x: 1));
    });

    test('keyframes builds a MultiKeyframeEffect carrying stops/easings/at', () {
      final animation = Animation.keyframes(
        const [Keyframe(y: 0), Keyframe(y: -0.1), Keyframe(y: 0)],
        easings: const [Ease.gentle, Ease.gentle],
        at: const [Time.zero, Time.frames(5), Time.frames(10)],
      );
      final effect = animation.effect as MultiKeyframeEffect;
      expect(effect.stops, hasLength(3));
      expect(effect.easings, const [Ease.gentle, Ease.gentle]);
      expect(effect.at, const [Time.zero, Time.frames(5), Time.frames(10)]);
    });

    test('keyframes takes its trigger via trigger: (at: names stop times, §6)', () {
      final animation = Animation.keyframes(
        const [Keyframe(y: 0), Keyframe(y: 1)],
        trigger: Trigger.previous,
      );
      expect(animation.at, Trigger.previous);
    });

    test('along builds a PathEffect with orient carried', () {
      final path = Path()..lineTo(0, 50);
      final animation = Animation.along(path, orient: false);
      final effect = animation.effect as PathEffect;
      expect(effect.path, same(path));
      expect(effect.orient, isFalse);
      expect((Animation.along(Path()..lineTo(1, 0)).effect as PathEffect).orient, isTrue);
    });

    test('custom carries the effect untouched', () {
      const effect = FakePixelEffect();
      const animation = Animation.custom(effect);
      expect(animation.effect, same(effect));
      expect(animation.effect, isA<AnimationEffect>());
    });
  });
}
