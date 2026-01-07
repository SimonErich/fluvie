import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/animations/entry/entry_animation.dart';

void main() {
  group('EntryAnimation', () {
    group('EntrySlideDirection', () {
      test('has all expected directions', () {
        expect(EntrySlideDirection.values, hasLength(4));
        expect(
            EntrySlideDirection.values, contains(EntrySlideDirection.fromLeft));
        expect(EntrySlideDirection.values,
            contains(EntrySlideDirection.fromRight));
        expect(
            EntrySlideDirection.values, contains(EntrySlideDirection.fromTop));
        expect(EntrySlideDirection.values,
            contains(EntrySlideDirection.fromBottom));
      });
    });

    group('WipeShape', () {
      test('has all expected shapes', () {
        expect(WipeShape.values, hasLength(5));
        expect(WipeShape.values, contains(WipeShape.circle));
        expect(WipeShape.values, contains(WipeShape.star));
        expect(WipeShape.values, contains(WipeShape.diamond));
        expect(WipeShape.values, contains(WipeShape.hexagon));
        expect(WipeShape.values, contains(WipeShape.heart));
      });
    });

    group('ElasticPopAnimation', () {
      test('creates with default values', () {
        const animation = ElasticPopAnimation();
        expect(animation.overshoot, 1.1);
        expect(animation.startScale, 0.0);
        expect(animation.alignment, Alignment.center);
      });

      test('creates with custom values', () {
        const animation = ElasticPopAnimation(
          overshoot: 1.3,
          startScale: 0.5,
          alignment: Alignment.topLeft,
        );
        expect(animation.overshoot, 1.3);
        expect(animation.startScale, 0.5);
        expect(animation.alignment, Alignment.topLeft);
      });

      test('has correct defaultDuration', () {
        const animation = ElasticPopAnimation();
        expect(animation.defaultDuration, 45);
      });

      test('has correct recommendedCurve', () {
        const animation = ElasticPopAnimation();
        expect(animation.recommendedCurve, Curves.easeOutBack);
      });

      test('apply returns Transform at progress 0', () {
        const animation = ElasticPopAnimation();
        const child = SizedBox();
        final result = animation.apply(child, 0.0);
        expect(result, isA<Transform>());
      });

      test('apply returns Transform at progress 0.5', () {
        const animation = ElasticPopAnimation();
        const child = SizedBox();
        final result = animation.apply(child, 0.5);
        expect(result, isA<Transform>());
      });

      test('apply returns Transform at progress 1.0', () {
        const animation = ElasticPopAnimation();
        const child = SizedBox();
        final result = animation.apply(child, 1.0);
        expect(result, isA<Transform>());
      });

      test('scales up then settles during animation', () {
        const animation = ElasticPopAnimation(overshoot: 1.2, startScale: 0.0);
        const child = SizedBox();
        // At 70% progress, should be at maximum overshoot
        expect(() => animation.apply(child, 0.7), returnsNormally);
        // At 85%, settling back
        expect(() => animation.apply(child, 0.85), returnsNormally);
        // At 100%, at 1.0
        expect(() => animation.apply(child, 1.0), returnsNormally);
      });

      test('factory constructor works', () {
        const animation = EntryAnimation.elasticPop(
          overshoot: 1.15,
          startScale: 0.0,
        );
        expect(animation, isA<ElasticPopAnimation>());
        const elastic = animation as ElasticPopAnimation;
        expect(elastic.overshoot, 1.15);
      });
    });

    group('StrobeRevealAnimation', () {
      test('creates with default values', () {
        const animation = StrobeRevealAnimation();
        expect(animation.flickerCount, 5);
        expect(animation.flickerIntensity, 0.7);
      });

      test('creates with custom values', () {
        const animation = StrobeRevealAnimation(
          flickerCount: 10,
          flickerIntensity: 0.5,
        );
        expect(animation.flickerCount, 10);
        expect(animation.flickerIntensity, 0.5);
      });

      test('has correct defaultDuration', () {
        const animation = StrobeRevealAnimation();
        expect(animation.defaultDuration, 30);
      });

      test('has correct recommendedCurve', () {
        const animation = StrobeRevealAnimation();
        expect(animation.recommendedCurve, Curves.linear);
      });

      test('apply returns Opacity widget', () {
        const animation = StrobeRevealAnimation();
        const child = SizedBox();
        final result = animation.apply(child, 0.5);
        expect(result, isA<Opacity>());
      });

      test('opacity increases over animation', () {
        const animation =
            StrobeRevealAnimation(flickerCount: 0, flickerIntensity: 0);
        const child = SizedBox();
        // Without flicker, opacity should simply increase from 0 to 1
        expect(() => animation.apply(child, 0.0), returnsNormally);
        expect(() => animation.apply(child, 0.5), returnsNormally);
        expect(() => animation.apply(child, 1.0), returnsNormally);
      });

      test('factory constructor works', () {
        const animation = EntryAnimation.strobeReveal(
          flickerCount: 8,
          flickerIntensity: 0.6,
        );
        expect(animation, isA<StrobeRevealAnimation>());
        const strobe = animation as StrobeRevealAnimation;
        expect(strobe.flickerCount, 8);
      });
    });

    group('GlitchSlideAnimation', () {
      test('creates with default values', () {
        const animation = GlitchSlideAnimation();
        expect(animation.direction, EntrySlideDirection.fromLeft);
        expect(animation.distance, 200);
        expect(animation.rgbOffset, 8);
        expect(animation.echoOpacity, 0.4);
      });

      test('creates with custom values', () {
        const animation = GlitchSlideAnimation(
          direction: EntrySlideDirection.fromRight,
          distance: 100,
          rgbOffset: 12,
          echoOpacity: 0.6,
        );
        expect(animation.direction, EntrySlideDirection.fromRight);
        expect(animation.distance, 100);
        expect(animation.rgbOffset, 12);
        expect(animation.echoOpacity, 0.6);
      });

      test('has correct defaultDuration', () {
        const animation = GlitchSlideAnimation();
        expect(animation.defaultDuration, 40);
      });

      test('has correct recommendedCurve', () {
        const animation = GlitchSlideAnimation();
        expect(animation.recommendedCurve, Curves.easeOutExpo);
      });

      test('apply returns Stack during glitch phase', () {
        const animation = GlitchSlideAnimation();
        const child = SizedBox();
        final result = animation.apply(child, 0.3);
        expect(result, isA<Stack>());
      });

      test('apply returns Transform after glitch phase', () {
        const animation = GlitchSlideAnimation();
        const child = SizedBox();
        final result = animation.apply(child, 0.9);
        expect(result, isA<Transform>());
      });

      test('works with all slide directions', () {
        const child = SizedBox();
        for (final direction in EntrySlideDirection.values) {
          final animation = GlitchSlideAnimation(direction: direction);
          expect(() => animation.apply(child, 0.5), returnsNormally);
        }
      });

      test('factory constructor works', () {
        const animation = EntryAnimation.glitchSlide(
          direction: EntrySlideDirection.fromBottom,
          distance: 150,
        );
        expect(animation, isA<GlitchSlideAnimation>());
        const glitch = animation as GlitchSlideAnimation;
        expect(glitch.direction, EntrySlideDirection.fromBottom);
      });
    });

    group('MaskedWipeAnimation', () {
      test('creates with default values', () {
        const animation = MaskedWipeAnimation();
        expect(animation.shape, WipeShape.circle);
        expect(animation.origin, Alignment.center);
      });

      test('creates with custom values', () {
        const animation = MaskedWipeAnimation(
          shape: WipeShape.star,
          origin: Alignment.topRight,
        );
        expect(animation.shape, WipeShape.star);
        expect(animation.origin, Alignment.topRight);
      });

      test('has correct defaultDuration', () {
        const animation = MaskedWipeAnimation();
        expect(animation.defaultDuration, 45);
      });

      test('has correct recommendedCurve', () {
        const animation = MaskedWipeAnimation();
        expect(animation.recommendedCurve, Curves.easeOutCubic);
      });

      test('apply returns ClipPath', () {
        const animation = MaskedWipeAnimation();
        const child = SizedBox();
        final result = animation.apply(child, 0.5);
        expect(result, isA<ClipPath>());
      });

      test('works with all wipe shapes', () {
        const child = SizedBox();
        for (final shape in WipeShape.values) {
          final animation = MaskedWipeAnimation(shape: shape);
          expect(() => animation.apply(child, 0.5), returnsNormally);
        }
      });

      test('works with various alignments', () {
        const child = SizedBox();
        const alignments = [
          Alignment.topLeft,
          Alignment.topCenter,
          Alignment.topRight,
          Alignment.centerLeft,
          Alignment.center,
          Alignment.centerRight,
          Alignment.bottomLeft,
          Alignment.bottomCenter,
          Alignment.bottomRight,
        ];
        for (final alignment in alignments) {
          final animation = MaskedWipeAnimation(origin: alignment);
          expect(() => animation.apply(child, 0.5), returnsNormally);
        }
      });

      test('factory constructor works', () {
        const animation = EntryAnimation.maskedWipe(
          shape: WipeShape.diamond,
          origin: Alignment.bottomLeft,
        );
        expect(animation, isA<MaskedWipeAnimation>());
        const masked = animation as MaskedWipeAnimation;
        expect(masked.shape, WipeShape.diamond);
      });
    });

    group('edge cases', () {
      test('all animations handle progress 0', () {
        const child = SizedBox();
        const animations = [
          ElasticPopAnimation(),
          StrobeRevealAnimation(),
          GlitchSlideAnimation(),
          MaskedWipeAnimation(),
        ];
        for (final animation in animations) {
          expect(() => animation.apply(child, 0.0), returnsNormally);
        }
      });

      test('all animations handle progress 1', () {
        const child = SizedBox();
        const animations = [
          ElasticPopAnimation(),
          StrobeRevealAnimation(),
          GlitchSlideAnimation(),
          MaskedWipeAnimation(),
        ];
        for (final animation in animations) {
          expect(() => animation.apply(child, 1.0), returnsNormally);
        }
      });

      test('all animations handle negative progress', () {
        const child = SizedBox();
        const animations = [
          ElasticPopAnimation(),
          StrobeRevealAnimation(),
          GlitchSlideAnimation(),
          MaskedWipeAnimation(),
        ];
        for (final animation in animations) {
          expect(() => animation.apply(child, -0.5), returnsNormally);
        }
      });

      test('all animations handle progress > 1', () {
        const child = SizedBox();
        const animations = [
          ElasticPopAnimation(),
          StrobeRevealAnimation(),
          GlitchSlideAnimation(),
          MaskedWipeAnimation(),
        ];
        for (final animation in animations) {
          expect(() => animation.apply(child, 1.5), returnsNormally);
        }
      });
    });
  });
}
