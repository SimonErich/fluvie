import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/effects/float_effect.dart';
import 'package:fluvie/src/animation/effects/keyframe_effect.dart';
import 'package:fluvie/src/animation/effects/multi_keyframe_effect.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/edge.dart';
import 'package:fluvie/src/core/keyframe.dart';
import 'package:fluvie/src/core/repeat.dart';
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

const _scope = TimeScopeData(fps: 30, startFrame: 0, durationFrames: 300);

void main() {
  group('float (D18)', () {
    test('five stops trace one vertical sine: natural, up, natural, down, natural', () {
      final effect = Animation.float().effect as MultiKeyframeEffect;
      expect(effect.stops, const [
        Keyframe.natural,
        Keyframe(y: -0.04),
        Keyframe.natural,
        Keyframe(y: 0.04),
        Keyframe.natural,
      ]);
      expect(effect.easings, const [Ease.gentle, Ease.gentle, Ease.gentle, Ease.gentle]);
      expect(effect.at, isNull, reason: 'stops are evenly spaced');
    });

    test('one period per cycle on a linear global clock', () {
      expect(Animation.float().duration, const Time.seconds(2.5));
      expect(Animation.float(period: const Time.seconds(2)).duration, const Time.seconds(2));
      expect(Animation.float().ease, Ease.linear);
      expect(Animation.float().repeat, const Repeat.forever());
    });

    test('amplitude scales the vertical stops (fractions of element height)', () {
      final effect = Animation.float(amplitude: 0.1).effect as MultiKeyframeEffect;
      expect(effect.stops[1], const Keyframe(y: -0.1));
      expect(effect.stops[3], const Keyframe(y: 0.1));
    });

    test('accepts a seed: parameter (D9 — the seeded API landed in Phase 9)', () {
      expect(
        Animation.float,
        isA<
          Animation Function({
            double amplitude,
            Time period,
            String? seed,
            Time delay,
            Trigger at,
            Stagger? stagger,
            Repeat? repeat,
            String? label,
          })
        >(),
      );
    });

    test('a seed routes to a during FloatEffect looping forever', () {
      final seeded = Animation.float(seed: 'leaf-7');
      expect(seeded.effect, isA<FloatEffect>());
      expect(seeded.phase, AnimationPhase.during);
      expect(seeded.repeat, const Repeat.forever());
      // The unseeded path is untouched: still the keyframe sine.
      expect(Animation.float().effect, isA<MultiKeyframeEffect>());
    });
  });

  group('pulse (D18)', () {
    test('scales min → max with a half-period tween and yoyo-forever repeat', () {
      final pulse = Animation.pulse();
      final effect = pulse.effect as KeyframeEffect;
      expect(effect.from, const Keyframe(scale: 0.97));
      expect(effect.to, const Keyframe(scale: 1.03));
      expect(pulse.duration, const Time.seconds(1.2) * 0.5);
      expect(pulse.repeat, const Repeat.forever(yoyo: true));
    });

    test('the default half-period resolves to 18 frames at 30 fps', () {
      expect(Animation.pulse().duration!.resolveFrames(_scope), 18);
    });

    test('min, max, and period are configurable', () {
      final pulse = Animation.pulse(min: 0.5, max: 1.5, period: const Time.frames(24));
      final effect = pulse.effect as KeyframeEffect;
      expect(effect.from, const Keyframe(scale: 0.5));
      expect(effect.to, const Keyframe(scale: 1.5));
      expect(pulse.duration!.resolveFrames(_scope), 12);
    });

    test('an explicit repeat overrides the yoyo-forever default', () {
      expect(Animation.pulse(repeat: const Repeat.times(2)).repeat, const Repeat.times(2));
    });
  });

  group('drift (D18)', () {
    test('travels from natural to edge × distance, linearly, with no repeat', () {
      for (final edge in Edge.values) {
        final drift = Animation.drift(to: edge);
        final effect = drift.effect as KeyframeEffect;
        expect(effect.from, Keyframe.natural);
        expect(effect.to, Keyframe(x: edge.dx * 0.1, y: edge.dy * 0.1));
        expect(drift.ease, Ease.linear);
        expect(drift.repeat, isNull, reason: 'one pass across the window');
      }
    });

    test('defaults to the right edge and scales with distance', () {
      final effect = Animation.drift().effect as KeyframeEffect;
      expect(effect.to, const Keyframe(x: 0.1, y: 0));
      final far = Animation.drift(to: Edge.top, distance: 0.5).effect as KeyframeEffect;
      expect(far.to, const Keyframe(x: 0, y: -0.5));
    });
  });

  group('spin (D18)', () {
    test('rotates one full turn per cycle, linearly, forever', () {
      final spin = Animation.spin();
      final effect = spin.effect as KeyframeEffect;
      expect(effect.from, const Keyframe(rotation: 0));
      expect(effect.to, const Keyframe(rotation: 1));
      expect(spin.duration, const Time.seconds(4));
      expect(spin.ease, Ease.linear);
      expect(spin.repeat, const Repeat.forever());
    });

    test('period sets the cycle length and an explicit repeat wins', () {
      final spin = Animation.spin(
        period: const Time.frames(240),
        repeat: const Repeat.times(2, gap: Time.frames(6)),
      );
      expect(spin.duration, const Time.frames(240));
      expect(spin.repeat, const Repeat.times(2, gap: Time.frames(6)));
    });
  });

  group('kenBurns (D18)', () {
    test('ends at (scale: zoom, x: −pan.dx·(zoom−1)/2, y: −pan.dy·(zoom−1)/2)', () {
      for (final pan in Edge.values) {
        final effect = Animation.kenBurns(pan: pan).effect as KeyframeEffect;
        expect(effect.from, Keyframe.natural);
        expect(
          effect.to,
          Keyframe(scale: 1.15, x: -pan.dx * (1.15 - 1) / 2, y: -pan.dy * (1.15 - 1) / 2),
          reason: 'pan $pan',
        );
      }
    });

    test('defaults pan left at zoom 1.15, linearly, one pass', () {
      final kenBurns = Animation.kenBurns();
      final effect = kenBurns.effect as KeyframeEffect;
      expect(effect.to, const Keyframe(scale: 1.15, x: (1.15 - 1) / 2, y: 0));
      expect(kenBurns.ease, Ease.linear);
      expect(kenBurns.repeat, isNull);
    });

    test('zoom scales both the end scale and the pan compensation', () {
      final effect = Animation.kenBurns(zoom: 1.3, pan: Edge.right).effect as KeyframeEffect;
      expect(effect.to, const Keyframe(scale: 1.3, x: -(1.3 - 1) / 2, y: 0));
    });
  });

  group('ambient phase and tail', () {
    final presets = <String, Animation Function()>{
      'float': Animation.float,
      'pulse': Animation.pulse,
      'drift': Animation.drift,
      'spin': Animation.spin,
      'kenBurns': Animation.kenBurns,
    };

    for (final entry in presets.entries) {
      test('${entry.key} plays during the window (D4 preset metadata)', () {
        expect(entry.value().phase, AnimationPhase.during);
      });
    }

    const delay = Time.frames(3);
    const at = Trigger.sceneStart;
    const stagger = Stagger.each(Time.frames(2));
    const label = 'ambient';

    final tailed = <String, Animation Function()>{
      'float': () => Animation.float(delay: delay, at: at, stagger: stagger, label: label),
      'pulse': () => Animation.pulse(delay: delay, at: at, stagger: stagger, label: label),
      'drift': () => Animation.drift(delay: delay, at: at, stagger: stagger, label: label),
      'spin': () => Animation.spin(delay: delay, at: at, stagger: stagger, label: label),
      'kenBurns': () => Animation.kenBurns(delay: delay, at: at, stagger: stagger, label: label),
    };

    for (final entry in tailed.entries) {
      test('${entry.key} forwards delay/at/stagger/label verbatim', () {
        final animation = entry.value();
        expect(animation.delay, delay);
        expect(animation.at, at);
        expect(animation.stagger, stagger);
        expect(animation.label, label);
      });
    }
  });
}
