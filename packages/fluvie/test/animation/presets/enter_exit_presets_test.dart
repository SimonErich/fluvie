import 'dart:math' as math;

import 'package:flutter/painting.dart' show Alignment;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/effects/keyframe_effect.dart';
import 'package:fluvie/src/animation/effects/mask_wipe_effect.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/edge.dart';
import 'package:fluvie/src/core/keyframe.dart';
import 'package:fluvie/src/core/repeat.dart';
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/timing.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/core/wipe_shape.dart';

/// Asserts [actual] expands to [expected]: same phase and the same
/// keyframe-effect endpoints (KeyframeEffect carries no `==`; D18 expansion
/// equality compares the parts).
void expectExpandsTo(Animation actual, Animation expected) {
  expect(actual.phase, expected.phase);
  final actualEffect = actual.effect as KeyframeEffect;
  final expectedEffect = expected.effect as KeyframeEffect;
  expect(actualEffect.from, expectedEffect.from);
  expect(actualEffect.to, expectedEffect.to);
}

void main() {
  group('fade presets (§6)', () {
    test('fadeIn ≡ Animation.from(Keyframe(opacity: 0)) — an enter', () {
      expectExpandsTo(Animation.fadeIn(), Animation.from(const Keyframe(opacity: 0)));
      expect(Animation.fadeIn().phase, AnimationPhase.enter);
    });

    test('fadeOut ≡ Animation.to(Keyframe(opacity: 0)) — an exit', () {
      expectExpandsTo(Animation.fadeOut(), Animation.to(const Keyframe(opacity: 0)));
      expect(Animation.fadeOut().phase, AnimationPhase.exit);
    });
  });

  group('slide presets (§6, Edge.dx/dy)', () {
    test('slideFadeIn defaults to the bottom edge: opacity 0, one height down', () {
      expectExpandsTo(
        Animation.slideFadeIn(),
        Animation.from(const Keyframe(opacity: 0, x: 0, y: 1)),
      );
    });

    test('slideFadeIn carries any edge through Edge.dx/dy', () {
      for (final edge in Edge.values) {
        expectExpandsTo(
          Animation.slideFadeIn(from: edge),
          Animation.from(Keyframe(opacity: 0, x: edge.dx, y: edge.dy)),
        );
      }
    });

    test('slideFadeOut defaults to the top edge: opacity 0, one height up — an exit', () {
      final out = Animation.slideFadeOut();
      expectExpandsTo(out, Animation.to(const Keyframe(opacity: 0, x: 0, y: -1)));
      expect(out.phase, AnimationPhase.exit);
    });

    test('slideFadeOut carries any edge through Edge.dx/dy', () {
      for (final edge in Edge.values) {
        expectExpandsTo(
          Animation.slideFadeOut(to: edge),
          Animation.to(Keyframe(opacity: 0, x: edge.dx, y: edge.dy)),
        );
      }
    });

    test('slideIn per edge ≡ from(Keyframe(x: dx, y: dy)) — enters', () {
      for (final edge in Edge.values) {
        final preset = Animation.slideIn(from: edge);
        expectExpandsTo(preset, Animation.from(Keyframe(x: edge.dx, y: edge.dy)));
        expect(preset.phase, AnimationPhase.enter);
      }
      // The default rises from the bottom.
      expectExpandsTo(Animation.slideIn(), Animation.from(const Keyframe(x: 0, y: 1)));
    });

    test('slideOut per edge ≡ to(Keyframe(x: dx, y: dy)) — exits', () {
      for (final edge in Edge.values) {
        final preset = Animation.slideOut(to: edge);
        expectExpandsTo(preset, Animation.to(Keyframe(x: edge.dx, y: edge.dy)));
        expect(preset.phase, AnimationPhase.exit);
      }
      // The default leaves through the top.
      expectExpandsTo(Animation.slideOut(), Animation.to(const Keyframe(x: 0, y: -1)));
    });
  });

  group('spring presets (D18)', () {
    test('pop scales from 0 with a spring-by-default enter', () {
      final pop = Animation.pop();
      expectExpandsTo(pop, Animation.from(const Keyframe(scale: 0)));
      expect(pop.phase, AnimationPhase.enter);
      expect(pop.spring, isNotNull);
      expect(pop.timing, isA<Spring>());
    });

    test('pop derives its damping from the D18 closed form', () {
      // ζ = −ln(o)/√(π² + ln²(o)), o = overshoot − 1, damping = 2ζ√(180·1).
      double dampingFor(double overshoot) {
        final lnO = math.log(overshoot - 1);
        final zeta = -lnO / math.sqrt(math.pi * math.pi + lnO * lnO);
        return 2 * zeta * math.sqrt(180.0 * 1.0);
      }

      final byDefault = Animation.pop().spring!;
      expect(byDefault.stiffness, 180);
      expect(byDefault.mass, 1);
      expect(byDefault.damping, closeTo(dampingFor(1.1), 1e-12));

      final flatter = Animation.pop(overshoot: 1.02).spring!;
      expect(flatter.damping, closeTo(dampingFor(1.02), 1e-12));
      // Less overshoot means more damping.
      expect(flatter.damping, greaterThan(byDefault.damping));
    });

    test('an explicit spring wins over the derived overshoot spring', () {
      expect(Animation.pop(spring: Spring.stiff).spring, Spring.stiff);
      expect(Animation.pop(overshoot: 1.5, spring: Spring.gentle).spring, Spring.gentle);
    });

    test('scaleIn ≡ from(Keyframe(scale: 0.85)) with Spring.snappy by default', () {
      final scaleIn = Animation.scaleIn();
      expectExpandsTo(scaleIn, Animation.from(const Keyframe(scale: 0.85)));
      expect(scaleIn.spring, Spring.snappy);
      expect(scaleIn.phase, AnimationPhase.enter);
      expect(Animation.scaleIn(from: 0.5).effect, isA<KeyframeEffect>());
      expectExpandsTo(Animation.scaleIn(from: 0.5), Animation.from(const Keyframe(scale: 0.5)));
      expect(Animation.scaleIn(spring: Spring.bouncy).spring, Spring.bouncy);
    });
  });

  group('blur presets (D18: blur-only)', () {
    test('blurIn ≡ from(Keyframe(blur: 12)) — no opacity in the keyframe', () {
      final blurIn = Animation.blurIn();
      expectExpandsTo(blurIn, Animation.from(const Keyframe(blur: 12)));
      expect((blurIn.effect as KeyframeEffect).from.opacity, isNull);
      expect(blurIn.phase, AnimationPhase.enter);
      expectExpandsTo(Animation.blurIn(sigma: 4), Animation.from(const Keyframe(blur: 4)));
    });

    test('blurOut ≡ to(Keyframe(blur: 12)) — an exit', () {
      final blurOut = Animation.blurOut();
      expectExpandsTo(blurOut, Animation.to(const Keyframe(blur: 12)));
      expect((blurOut.effect as KeyframeEffect).to.opacity, isNull);
      expect(blurOut.phase, AnimationPhase.exit);
      expectExpandsTo(Animation.blurOut(sigma: 30), Animation.to(const Keyframe(blur: 30)));
    });
  });

  group('maskWipeIn preset', () {
    test('carries a MaskWipeEffect with the shape and origin — an enter', () {
      final wipe = Animation.maskWipeIn();
      final effect = wipe.effect as MaskWipeEffect;
      expect(effect.shape, WipeShape.circle);
      expect(effect.origin, Alignment.center);
      expect(wipe.phase, AnimationPhase.enter);

      final custom = Animation.maskWipeIn(shape: WipeShape.diagonal, origin: Alignment.topRight);
      final customEffect = custom.effect as MaskWipeEffect;
      expect(customEffect.shape, WipeShape.diagonal);
      expect(customEffect.origin, Alignment.topRight);
    });
  });

  group('maskWipeOut preset', () {
    test('carries a reversed MaskWipeEffect — an exit', () {
      final wipe = Animation.maskWipeOut();
      final effect = wipe.effect as MaskWipeEffect;
      expect(effect.shape, WipeShape.circle);
      expect(effect.origin, Alignment.center);
      expect(effect.reverse, isTrue);
      expect(wipe.phase, AnimationPhase.exit);
    });
  });

  group('scaleOut preset', () {
    test('scales toward its target on a spring-by-default exit', () {
      final out = Animation.scaleOut();
      expectExpandsTo(out, Animation.to(const Keyframe(scale: 0.85)));
      expect(out.phase, AnimationPhase.exit);
      expect(out.spring, isNotNull);
      expect(out.timing, isA<Spring>());
    });
  });

  group('common tail forwarding', () {
    const delay = Time.frames(4);
    const at = Trigger.sceneEnd;
    const stagger = Stagger.each(Time.frames(2));
    const repeat = Repeat.times(2);
    const label = 'tail';

    final presets = <String, Animation Function()>{
      'fadeIn': () =>
          Animation.fadeIn(delay: delay, at: at, stagger: stagger, repeat: repeat, label: label),
      'fadeOut': () =>
          Animation.fadeOut(delay: delay, at: at, stagger: stagger, repeat: repeat, label: label),
      'slideIn': () =>
          Animation.slideIn(delay: delay, at: at, stagger: stagger, repeat: repeat, label: label),
      'slideOut': () =>
          Animation.slideOut(delay: delay, at: at, stagger: stagger, repeat: repeat, label: label),
      'slideFadeIn': () => Animation.slideFadeIn(
        delay: delay,
        at: at,
        stagger: stagger,
        repeat: repeat,
        label: label,
      ),
      'pop': () =>
          Animation.pop(delay: delay, at: at, stagger: stagger, repeat: repeat, label: label),
      'scaleIn': () =>
          Animation.scaleIn(delay: delay, at: at, stagger: stagger, repeat: repeat, label: label),
      'blurIn': () =>
          Animation.blurIn(delay: delay, at: at, stagger: stagger, repeat: repeat, label: label),
      'blurOut': () =>
          Animation.blurOut(delay: delay, at: at, stagger: stagger, repeat: repeat, label: label),
      'maskWipeIn': () => Animation.maskWipeIn(
        delay: delay,
        at: at,
        stagger: stagger,
        repeat: repeat,
        label: label,
      ),
    };

    for (final entry in presets.entries) {
      test('${entry.key} forwards delay/at/stagger/repeat/label verbatim', () {
        final animation = entry.value();
        expect(animation.delay, delay);
        expect(animation.at, at);
        expect(animation.stagger, stagger);
        expect(animation.repeat, repeat);
        expect(animation.label, label);
      });
    }

    test('tween-timing presets forward duration, ease, and spring', () {
      final fade = Animation.fadeIn(
        duration: const Time.frames(20),
        ease: Ease.snappy,
      );
      expect(fade.duration, const Time.frames(20));
      expect(fade.ease, Ease.snappy);
      expect(fade.timing, const Tween(Time.frames(20), ease: Ease.snappy));

      final sprung = Animation.slideFadeIn(spring: Spring.bouncy);
      expect(sprung.spring, Spring.bouncy);
      expect(sprung.timing, Spring.bouncy);

      // Unset timing stays null so the Defaults cascade applies (D3/D14).
      expect(Animation.fadeIn().timing, isNull);
    });
  });
}
