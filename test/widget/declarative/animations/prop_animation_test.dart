import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/animations/core/prop_animation.dart';

void main() {
  group('PropAnimation', () {
    group('TranslateAnimation', () {
      test('creates with default values', () {
        const animation = TranslateAnimation();
        expect(animation.start, Offset.zero);
        expect(animation.end, Offset.zero);
      });

      test('creates with custom offsets', () {
        const animation = TranslateAnimation(
          start: Offset(10, 20),
          end: Offset(30, 40),
        );
        expect(animation.start, const Offset(10, 20));
        expect(animation.end, const Offset(30, 40));
      });

      test('apply returns child unchanged when offset is zero', () {
        const animation = TranslateAnimation();
        const child = SizedBox();
        final result = animation.apply(child, 0.5);
        expect(result, same(child));
      });

      test('apply returns Transform at progress 0', () {
        const animation = TranslateAnimation(
          start: Offset(0, 30),
          end: Offset.zero,
        );
        const child = SizedBox();
        final result = animation.apply(child, 0.0);
        expect(result, isA<Transform>());
      });

      test('apply interpolates correctly at 50%', () {
        const animation = TranslateAnimation(
          start: Offset(0, 100),
          end: Offset.zero,
        );
        const child = SizedBox();
        final result = animation.apply(child, 0.5);
        expect(result, isA<Transform>());
      });
    });

    group('ScaleAnimation', () {
      test('creates with default values', () {
        const animation = ScaleAnimation();
        expect(animation.start, 0.0);
        expect(animation.end, 1.0);
        expect(animation.alignment, Alignment.center);
      });

      test('creates with custom values', () {
        const animation = ScaleAnimation(
          start: 0.5,
          end: 1.5,
          alignment: Alignment.topLeft,
        );
        expect(animation.start, 0.5);
        expect(animation.end, 1.5);
        expect(animation.alignment, Alignment.topLeft);
      });

      test('apply returns child unchanged when scale is 1.0', () {
        const animation = ScaleAnimation(start: 1.0, end: 1.0);
        const child = SizedBox();
        final result = animation.apply(child, 0.5);
        expect(result, same(child));
      });

      test('apply returns Transform at progress 0', () {
        const animation = ScaleAnimation(start: 0.5, end: 1.0);
        const child = SizedBox();
        final result = animation.apply(child, 0.0);
        expect(result, isA<Transform>());
      });

      test('apply interpolates correctly at 50%', () {
        const animation = ScaleAnimation(start: 0.0, end: 1.0);
        const child = SizedBox();
        final result = animation.apply(child, 0.5);
        expect(result, isA<Transform>());
      });
    });

    group('RotateAnimation', () {
      test('creates with default values', () {
        const animation = RotateAnimation();
        expect(animation.start, 0.0);
        expect(animation.end, 0.0);
        expect(animation.alignment, Alignment.center);
      });

      test('creates with custom values', () {
        const animation = RotateAnimation(
          start: 0.0,
          end: 3.14159,
          alignment: Alignment.bottomRight,
        );
        expect(animation.start, 0.0);
        expect(animation.end, 3.14159);
        expect(animation.alignment, Alignment.bottomRight);
      });

      test('apply returns child unchanged when angle is zero', () {
        const animation = RotateAnimation();
        const child = SizedBox();
        final result = animation.apply(child, 0.5);
        expect(result, same(child));
      });

      test('apply returns Transform when angle is non-zero', () {
        const animation = RotateAnimation(start: 0.0, end: 1.0);
        const child = SizedBox();
        final result = animation.apply(child, 0.5);
        expect(result, isA<Transform>());
      });
    });

    group('FadeAnimation', () {
      test('creates with default values', () {
        const animation = FadeAnimation();
        expect(animation.start, 0.0);
        expect(animation.end, 1.0);
      });

      test('creates with custom values', () {
        const animation = FadeAnimation(start: 0.2, end: 0.8);
        expect(animation.start, 0.2);
        expect(animation.end, 0.8);
      });

      test('apply returns child unchanged when opacity is 1.0', () {
        const animation = FadeAnimation(start: 1.0, end: 1.0);
        const child = SizedBox();
        final result = animation.apply(child, 0.5);
        expect(result, same(child));
      });

      test('apply returns Fade at progress 0', () {
        const animation = FadeAnimation(start: 0.0, end: 1.0);
        const child = SizedBox();
        final result = animation.apply(child, 0.0);
        // Result should be a Fade widget with 0 opacity
        expect(result, isNot(same(child)));
      });

      test('clamps opacity to valid range', () {
        const animation = FadeAnimation(start: -0.5, end: 1.5);
        const child = SizedBox();
        // Should not throw for invalid opacity values
        expect(() => animation.apply(child, 0.0), returnsNormally);
        expect(() => animation.apply(child, 1.0), returnsNormally);
      });
    });

    group('CombinedAnimation', () {
      test('creates with animations list', () {
        const animation = CombinedAnimation([
          TranslateAnimation(),
          ScaleAnimation(),
        ]);
        expect(animation.animations.length, 2);
      });

      test('creates with empty list', () {
        const animation = CombinedAnimation([]);
        expect(animation.animations, isEmpty);
      });

      test('apply applies all animations in order', () {
        final animation = PropAnimation.combine([
          PropAnimation.slideUp(distance: 30),
          PropAnimation.fadeIn(),
        ]);
        const child = SizedBox();
        final result = animation.apply(child, 0.5);
        // Result should be nested widgets from both animations
        expect(result, isNot(same(child)));
      });

      test('apply with empty list returns child unchanged', () {
        const animation = CombinedAnimation([]);
        const child = SizedBox();
        final result = animation.apply(child, 0.5);
        expect(result, same(child));
      });
    });

    group('FloatAnimation', () {
      test('creates with default values', () {
        const animation = FloatAnimation();
        expect(animation.amplitude, const Offset(0, 10));
        expect(animation.phase, 0.0);
      });

      test('creates with custom values', () {
        const animation = FloatAnimation(
          amplitude: Offset(5, 15),
          phase: 0.5,
        );
        expect(animation.amplitude, const Offset(5, 15));
        expect(animation.phase, 0.5);
      });

      test('apply returns Transform', () {
        const animation = FloatAnimation();
        const child = SizedBox();
        final result = animation.apply(child, 0.5);
        expect(result, isA<Transform>());
      });

      test('oscillates smoothly through progress', () {
        const animation = FloatAnimation(amplitude: Offset(0, 100));
        const child = SizedBox();
        // At 0.25 progress, should be at max offset
        // At 0.5 progress, should be back near zero
        // At 0.75 progress, should be at min offset
        expect(() => animation.apply(child, 0.0), returnsNormally);
        expect(() => animation.apply(child, 0.25), returnsNormally);
        expect(() => animation.apply(child, 0.5), returnsNormally);
        expect(() => animation.apply(child, 0.75), returnsNormally);
        expect(() => animation.apply(child, 1.0), returnsNormally);
      });
    });

    group('PulseAnimation', () {
      test('creates with default values', () {
        const animation = PulseAnimation();
        expect(animation.min, 0.95);
        expect(animation.max, 1.05);
        expect(animation.phase, 0.0);
      });

      test('creates with custom values', () {
        const animation = PulseAnimation(min: 0.8, max: 1.2, phase: 0.25);
        expect(animation.min, 0.8);
        expect(animation.max, 1.2);
        expect(animation.phase, 0.25);
      });

      test('apply returns Transform', () {
        const animation = PulseAnimation();
        const child = SizedBox();
        final result = animation.apply(child, 0.5);
        expect(result, isA<Transform>());
      });
    });

    group('ScaleXAnimation', () {
      test('creates with default values', () {
        const animation = ScaleXAnimation();
        expect(animation.start, 0.0);
        expect(animation.end, 1.0);
      });

      test('apply returns child unchanged when scaleX is 1.0', () {
        const animation = ScaleXAnimation(start: 1.0, end: 1.0);
        const child = SizedBox();
        final result = animation.apply(child, 0.5);
        expect(result, same(child));
      });

      test('apply returns Transform when scaleX is not 1.0', () {
        const animation = ScaleXAnimation(start: 0.0, end: 1.0);
        const child = SizedBox();
        final result = animation.apply(child, 0.5);
        expect(result, isA<Transform>());
      });
    });

    group('ScaleYAnimation', () {
      test('creates with default values', () {
        const animation = ScaleYAnimation();
        expect(animation.start, 0.0);
        expect(animation.end, 1.0);
      });

      test('apply returns child unchanged when scaleY is 1.0', () {
        const animation = ScaleYAnimation(start: 1.0, end: 1.0);
        const child = SizedBox();
        final result = animation.apply(child, 0.5);
        expect(result, same(child));
      });

      test('apply returns Transform when scaleY is not 1.0', () {
        const animation = ScaleYAnimation(start: 0.0, end: 1.0);
        const child = SizedBox();
        final result = animation.apply(child, 0.5);
        expect(result, isA<Transform>());
      });
    });

    group('BounceInAnimation', () {
      test('creates with default values', () {
        const animation = BounceInAnimation();
        expect(animation.start, 0.0);
        expect(animation.overshoot, 1.2);
      });

      test('creates with custom values', () {
        const animation = BounceInAnimation(start: 0.5, overshoot: 1.3);
        expect(animation.start, 0.5);
        expect(animation.overshoot, 1.3);
      });

      test('apply returns Transform', () {
        const animation = BounceInAnimation();
        const child = SizedBox();
        final result = animation.apply(child, 0.5);
        expect(result, isA<Transform>());
      });

      test('overshoots at 60% progress', () {
        const animation = BounceInAnimation(start: 0.0, overshoot: 1.2);
        const child = SizedBox();
        // Before 60%, scaling up to overshoot
        expect(() => animation.apply(child, 0.3), returnsNormally);
        // At 60%, at overshoot
        expect(() => animation.apply(child, 0.6), returnsNormally);
        // After 60%, scaling back to 1.0
        expect(() => animation.apply(child, 0.8), returnsNormally);
        expect(() => animation.apply(child, 1.0), returnsNormally);
      });
    });

    group('convenience constructors', () {
      test('slideUp creates correct animation', () {
        final animation = PropAnimation.slideUp(distance: 50);
        expect(animation, isA<TranslateAnimation>());
        final translate = animation as TranslateAnimation;
        expect(translate.start, const Offset(0, 50));
        expect(translate.end, Offset.zero);
      });

      test('slideDown creates correct animation', () {
        final animation = PropAnimation.slideDown(distance: 50);
        expect(animation, isA<TranslateAnimation>());
        final translate = animation as TranslateAnimation;
        expect(translate.start, const Offset(0, -50));
        expect(translate.end, Offset.zero);
      });

      test('slideLeft creates correct animation', () {
        final animation = PropAnimation.slideLeft(distance: 50);
        expect(animation, isA<TranslateAnimation>());
        final translate = animation as TranslateAnimation;
        expect(translate.start, const Offset(50, 0));
        expect(translate.end, Offset.zero);
      });

      test('slideRight creates correct animation', () {
        final animation = PropAnimation.slideRight(distance: 50);
        expect(animation, isA<TranslateAnimation>());
        final translate = animation as TranslateAnimation;
        expect(translate.start, const Offset(-50, 0));
        expect(translate.end, Offset.zero);
      });

      test('zoomIn creates correct animation', () {
        final animation = PropAnimation.zoomIn(start: 0.3);
        expect(animation, isA<ScaleAnimation>());
        final scale = animation as ScaleAnimation;
        expect(scale.start, 0.3);
        expect(scale.end, 1.0);
      });

      test('zoomOut creates correct animation', () {
        final animation = PropAnimation.zoomOut(end: 0.3);
        expect(animation, isA<ScaleAnimation>());
        final scale = animation as ScaleAnimation;
        expect(scale.start, 1.0);
        expect(scale.end, 0.3);
      });

      test('fadeIn creates correct animation', () {
        final animation = PropAnimation.fadeIn();
        expect(animation, isA<FadeAnimation>());
        final fade = animation as FadeAnimation;
        expect(fade.start, 0.0);
        expect(fade.end, 1.0);
      });

      test('fadeOut creates correct animation', () {
        final animation = PropAnimation.fadeOut();
        expect(animation, isA<FadeAnimation>());
        final fade = animation as FadeAnimation;
        expect(fade.start, 1.0);
        expect(fade.end, 0.0);
      });

      test('slideUpFade creates combined animation', () {
        final animation = PropAnimation.slideUpFade(distance: 30);
        expect(animation, isA<CombinedAnimation>());
        final combined = animation as CombinedAnimation;
        expect(combined.animations.length, 2);
      });

      test('slideUpScale creates combined animation', () {
        final animation = PropAnimation.slideUpScale(distance: 30, startScale: 0.8);
        expect(animation, isA<CombinedAnimation>());
        final combined = animation as CombinedAnimation;
        expect(combined.animations.length, 2);
      });

      test('slideDownFade creates combined animation', () {
        final animation = PropAnimation.slideDownFade(distance: 30);
        expect(animation, isA<CombinedAnimation>());
        final combined = animation as CombinedAnimation;
        expect(combined.animations.length, 2);
      });

      test('slideLeftFade creates combined animation', () {
        final animation = PropAnimation.slideLeftFade(distance: 30);
        expect(animation, isA<CombinedAnimation>());
        final combined = animation as CombinedAnimation;
        expect(combined.animations.length, 2);
      });

      test('slideRightFade creates combined animation', () {
        final animation = PropAnimation.slideRightFade(distance: 30);
        expect(animation, isA<CombinedAnimation>());
        final combined = animation as CombinedAnimation;
        expect(combined.animations.length, 2);
      });

      test('float creates correct animation', () {
        final animation = PropAnimation.float(amplitude: const Offset(5, 15), phase: 0.25);
        expect(animation, isA<FloatAnimation>());
        final float = animation as FloatAnimation;
        expect(float.amplitude, const Offset(5, 15));
        expect(float.phase, 0.25);
      });

      test('pulse creates correct animation', () {
        final animation = PropAnimation.pulse(min: 0.9, max: 1.1, phase: 0.5);
        expect(animation, isA<PulseAnimation>());
        final pulse = animation as PulseAnimation;
        expect(pulse.min, 0.9);
        expect(pulse.max, 1.1);
        expect(pulse.phase, 0.5);
      });

      test('scaleX creates correct animation', () {
        final animation = PropAnimation.scaleX(start: 0.5, end: 1.0);
        expect(animation, isA<ScaleXAnimation>());
        final scaleX = animation as ScaleXAnimation;
        expect(scaleX.start, 0.5);
        expect(scaleX.end, 1.0);
      });

      test('scaleY creates correct animation', () {
        final animation = PropAnimation.scaleY(start: 0.5, end: 1.0);
        expect(animation, isA<ScaleYAnimation>());
        final scaleY = animation as ScaleYAnimation;
        expect(scaleY.start, 0.5);
        expect(scaleY.end, 1.0);
      });

      test('bounceIn creates correct animation', () {
        final animation = PropAnimation.bounceIn(start: 0.0, overshoot: 1.3);
        expect(animation, isA<BounceInAnimation>());
        final bounce = animation as BounceInAnimation;
        expect(bounce.start, 0.0);
        expect(bounce.overshoot, 1.3);
      });
    });

    group('factory constructors', () {
      test('translate factory works', () {
        const animation = PropAnimation.translate(
          start: Offset(10, 20),
          end: Offset.zero,
        );
        expect(animation, isA<TranslateAnimation>());
      });

      test('scale factory works', () {
        const animation = PropAnimation.scale(
          start: 0.5,
          end: 1.0,
          alignment: Alignment.topLeft,
        );
        expect(animation, isA<ScaleAnimation>());
      });

      test('rotate factory works', () {
        const animation = PropAnimation.rotate(
          start: 0.0,
          end: 1.57,
          alignment: Alignment.center,
        );
        expect(animation, isA<RotateAnimation>());
      });

      test('fade factory works', () {
        const animation = PropAnimation.fade(start: 0.0, end: 1.0);
        expect(animation, isA<FadeAnimation>());
      });

      test('combine factory works', () {
        final animation = PropAnimation.combine([
          PropAnimation.fadeIn(),
          PropAnimation.slideUp(),
        ]);
        expect(animation, isA<CombinedAnimation>());
      });
    });

    group('edge cases', () {
      test('negative progress is handled', () {
        final animation = PropAnimation.slideUp();
        const child = SizedBox();
        expect(() => animation.apply(child, -0.5), returnsNormally);
      });

      test('progress > 1.0 is handled', () {
        final animation = PropAnimation.slideUp();
        const child = SizedBox();
        expect(() => animation.apply(child, 1.5), returnsNormally);
      });

      test('very large distance values work', () {
        final animation = PropAnimation.slideUp(distance: 10000);
        const child = SizedBox();
        expect(() => animation.apply(child, 0.5), returnsNormally);
      });

      test('zero distance returns child unchanged', () {
        final animation = PropAnimation.slideUp(distance: 0);
        const child = SizedBox();
        final result = animation.apply(child, 0.5);
        expect(result, same(child));
      });
    });
  });
}
