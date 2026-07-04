// Epic 9.3 (WI-15): the seeded `Animation.float(seed:)` variant. The
// `seed == null` path must stay the existing pure-sine `buildFloat`
// (byte-identical, so its golden is untouched); `seed != null` mounts a
// transform-class `FloatEffect` that adds a low-amplitude, reproducible noise
// offset which stays continuous across the loop wrap.
import 'dart:math' as math;

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/effect_kind.dart';
import 'package:fluvie/src/animation/effects/float_effect.dart';
import 'package:fluvie/src/animation/effects/keyframe_effect.dart';
import 'package:fluvie/src/animation/effects/multi_keyframe_effect.dart';
import 'package:fluvie/src/animation/presets/ambient_presets.dart';
import 'package:fluvie/src/animation/presets/preset_tail.dart';
import 'package:fluvie/src/core/noise/value_noise.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

const _probeKey = Key('probe');
const _child = SizedBox(key: _probeKey, width: 10, height: 10);

/// Bundles a do-nothing ambient tail for `buildFloat`.
const AmbientTail _tail = (
  delay: Time.zero,
  at: Trigger.auto,
  stagger: null,
  repeat: null,
  label: null,
);

/// Mounts [built] under a frame clock at [frame].
Widget _host(Widget built, {required int frame}) => Directionality(
  textDirection: TextDirection.ltr,
  child: FrameProvider(
    frame: frame,
    child: TimeScopeProvider(
      scope: const TimeScopeData(fps: 30, startFrame: 0, durationFrames: 1000),
      child: SizedBox(
        width: 100,
        height: 100,
        child: Center(child: built),
      ),
    ),
  ),
);

FractionalTranslation _translation(WidgetTester tester) =>
    tester.widget<FractionalTranslation>(find.byType(FractionalTranslation));

void main() {
  group('Animation.float(seed:) routing (WI-15)', () {
    test('seed == null produces the unchanged keyframe float', () {
      final seeded = Animation.float();
      // The existing pure-sine path: a multi-keyframe effect, never FloatEffect.
      expect(seeded.effect, isA<MultiKeyframeEffect>());
      expect(seeded.effect, isNot(isA<FloatEffect>()));
    });

    test('seed == null is byte-identical to the existing buildFloat', () {
      final viaFacade = Animation.float();
      final viaBuilder = buildFloat(0.04, 0.4, _tail);
      // Same effect (the keyframe stops) and same loop/phase tail.
      expect(viaFacade.effect.toString(), viaBuilder.effect.toString());
      expect(viaFacade.phase, viaBuilder.phase);
      expect(viaFacade.duration, viaBuilder.duration);
      expect(viaFacade.repeat, viaBuilder.repeat);
    });

    test('seed != null mounts a transform-class FloatEffect', () {
      final seeded = Animation.float(seed: 'leaf-7');
      expect(seeded.effect, isA<FloatEffect>());
      expect(effectKindOf(seeded.effect), EffectKind.transform);
      expect(seeded.effect, isNot(isA<PixelAnimationEffect>()));
    });
  });

  group('FloatEffect — fields', () {
    test('carries its amplitude, frequency, and seed', () {
      const effect = FloatEffect(amplitude: 0.06, frequency: 0.5, seed: 's');
      expect(effect.amplitude, 0.06);
      expect(effect.frequency, 0.5);
      expect(effect.seed, 's');
    });
  });

  group('FloatEffect.offsetAt — base shape matches the pure sine', () {
    // The cycle is 1/frequency seconds = 75 frames at 30 fps.
    const cycle = 75;
    const amp = 0.04;

    test('rests at 0 at the cycle start', () {
      final base = FloatEffect.baseOffset(0, cycle, amp);
      expect(base, closeTo(0, 1e-9));
    });

    test('peaks up (negative y) near a quarter cycle', () {
      // buildFloat goes to -amplitude (up) at 25% of the cycle; the nearest
      // whole frame (18 of 75) lands within a frame's slope of the peak.
      final base = FloatEffect.baseOffset(cycle ~/ 4, cycle, amp);
      expect(base, closeTo(-amp, amp * 0.05));
      expect(base, lessThan(0), reason: 'up is negative y');
    });

    test('peaks down (positive y) near three-quarters', () {
      final base = FloatEffect.baseOffset((cycle * 3) ~/ 4, cycle, amp);
      expect(base, closeTo(amp, amp * 0.05));
      expect(base, greaterThan(0), reason: 'down is positive y');
    });
  });

  group('FloatEffect — determinism (§22)', () {
    test('same seed and frame give the same offset every call', () {
      const noise = ValueNoise();
      final a = FloatEffect.offsetAt(
        frame: 31,
        cycleFrames: 75,
        amplitude: 0.04,
        seed: 'leaf-7',
        noise: noise,
      );
      final b = FloatEffect.offsetAt(
        frame: 31,
        cycleFrames: 75,
        amplitude: 0.04,
        seed: 'leaf-7',
        noise: noise,
      );
      expect(a, b);
    });

    test('different seeds give different offsets', () {
      const noise = ValueNoise();
      final a = FloatEffect.offsetAt(
        frame: 31,
        cycleFrames: 75,
        amplitude: 0.04,
        seed: 'leaf-7',
        noise: noise,
      );
      final b = FloatEffect.offsetAt(
        frame: 31,
        cycleFrames: 75,
        amplitude: 0.04,
        seed: 'rock-2',
        noise: noise,
      );
      expect(a, isNot(closeTo(b, 1e-12)));
    });

    testWidgets('two pumps at the same frame mount the identical offset', (tester) async {
      const effect = FloatEffect(seed: 'leaf-7');
      await tester.pumpWidget(_host(effect.build(_child, 0), frame: 31));
      final first = _translation(tester).translation;
      await tester.pumpWidget(_host(effect.build(_child, 0), frame: 31));
      final second = _translation(tester).translation;
      expect(first, second);
    });
  });

  group('FloatEffect — the noise actually perturbs the sine', () {
    test('the seeded offset differs from the bare base sine', () {
      const noise = ValueNoise();
      const cycle = 75;
      const amp = 0.04;
      var sawDifference = false;
      for (var frame = 0; frame < cycle; frame++) {
        final base = FloatEffect.baseOffset(frame, cycle, amp);
        final seeded = FloatEffect.offsetAt(
          frame: frame,
          cycleFrames: cycle,
          amplitude: amp,
          seed: 'leaf-7',
          noise: noise,
        );
        if ((seeded - base).abs() > 1e-6) sawDifference = true;
      }
      expect(sawDifference, isTrue, reason: 'the seed must add an organic offset');
    });

    test('the noise term stays low-amplitude (never overwhelms the sine)', () {
      const noise = ValueNoise();
      const cycle = 75;
      const amp = 0.04;
      for (var frame = 0; frame < cycle; frame++) {
        final base = FloatEffect.baseOffset(frame, cycle, amp);
        final seeded = FloatEffect.offsetAt(
          frame: frame,
          cycleFrames: cycle,
          amplitude: amp,
          seed: 'leaf-7',
          noise: noise,
        );
        // The noise stays within half the amplitude of the base sine.
        expect((seeded - base).abs(), lessThanOrEqualTo(amp * 0.5 + 1e-9));
      }
    });
  });

  group('FloatEffect — loop continuity (no jump at the wrap)', () {
    test('the last frame of a cycle and the first of the next are continuous', () {
      const noise = ValueNoise();
      const cycle = 75;
      const amp = 0.04;
      // One frame's worth of motion is the largest step inside the cycle.
      var maxInnerStep = 0.0;
      for (var frame = 1; frame < cycle; frame++) {
        final prev = FloatEffect.offsetAt(
          frame: frame - 1,
          cycleFrames: cycle,
          amplitude: amp,
          seed: 'leaf-7',
          noise: noise,
        );
        final cur = FloatEffect.offsetAt(
          frame: frame,
          cycleFrames: cycle,
          amplitude: amp,
          seed: 'leaf-7',
          noise: noise,
        );
        maxInnerStep = math.max(maxInnerStep, (cur - prev).abs());
      }
      final lastOfCycle = FloatEffect.offsetAt(
        frame: cycle - 1,
        cycleFrames: cycle,
        amplitude: amp,
        seed: 'leaf-7',
        noise: noise,
      );
      final firstOfNext = FloatEffect.offsetAt(
        frame: cycle,
        cycleFrames: cycle,
        amplitude: amp,
        seed: 'leaf-7',
        noise: noise,
      );
      final wrapStep = (firstOfNext - lastOfCycle).abs();
      expect(
        wrapStep,
        lessThanOrEqualTo(maxInnerStep + 1e-9),
        reason: 'the wrap step must not exceed a normal one-frame step',
      );
    });

    test('the offset is exactly periodic over the cycle', () {
      const noise = ValueNoise();
      const cycle = 75;
      const amp = 0.04;
      final atZero = FloatEffect.offsetAt(
        frame: 0,
        cycleFrames: cycle,
        amplitude: amp,
        seed: 'leaf-7',
        noise: noise,
      );
      final atCycle = FloatEffect.offsetAt(
        frame: cycle,
        cycleFrames: cycle,
        amplitude: amp,
        seed: 'leaf-7',
        noise: noise,
      );
      expect(atCycle, closeTo(atZero, 1e-9));
    });
  });

  group('FloatEffect — frame clock', () {
    testWidgets('translates the child vertically by the frame offset', (tester) async {
      const effect = FloatEffect(seed: 'leaf-7');
      await tester.pumpWidget(_host(effect.build(_child, 0), frame: 19));
      final dy = _translation(tester).translation.dy;
      expect(dy, isNot(0), reason: 'a quarter into the cycle the float is off-center');
      // Horizontal stays put — float is purely vertical.
      expect(_translation(tester).translation.dx, 0);
    });
  });

  group('KeyframeEffect sanity (the unseeded path is unaffected)', () {
    test('buildFloat still expands to keyframe stops, not a keyframe effect pair', () {
      final unseeded = buildFloat(0.04, 0.4, _tail);
      expect(unseeded.effect, isNot(isA<KeyframeEffect>()));
      expect(unseeded.effect, isA<MultiKeyframeEffect>());
    });
  });
}
