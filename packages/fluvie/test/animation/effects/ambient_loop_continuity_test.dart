// Epic 9.3 (WI-16) acceptance: the ambient presets loop without a visible jump
// at the cycle wrap. For each looping preset the animated value at the last
// frame of one cycle and the first of the next must differ by no more than a
// normal one-frame step inside the cycle — computed via MotionRunner.progress
// at the wrap boundary, the same path the pipeline drives (untagged, pure).
import 'dart:math' as math;

import 'package:flutter/animation.dart' show Curve;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/effects/float_effect.dart';
import 'package:fluvie/src/animation/effects/keyframe_animation_effect.dart';
import 'package:fluvie/src/animation/effects/multi_keyframe_effect.dart';
import 'package:fluvie/src/animation/runtime/motion_runner.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/keyframe.dart';
import 'package:fluvie/src/core/noise/value_noise.dart';
import 'package:fluvie/src/core/repeat.dart';
import 'package:fluvie/src/timing/resolver/trigger_resolver.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

const _fps = 30;

/// The animation-level curve [animation] runs under: its own [Animation.ease]
/// or the package default the cascade would supply for an ambient `during`.
Curve _curve(Animation animation) => animation.ease ?? Ease.smooth;

/// The keyframe value [animation]'s effect produces at the shaped [progress]
/// of one cycle, resolving any explicit stop positions against [cycleFrames]
/// exactly as `animation_pipeline._keyframeOf` does.
Keyframe _keyframeAt(Animation animation, double progress, int cycleFrames) {
  final effect = animation.effect as KeyframeAnimationEffect;
  if (effect is MultiKeyframeEffect && effect.at != null) {
    final scope = TimeScopeData(fps: _fps, startFrame: 0, durationFrames: cycleFrames);
    final fractions = [for (final t in effect.at!) t.resolveFrames(scope) / cycleFrames];
    return effect.keyframeAt(progress, stopFractions: fractions);
  }
  return effect.keyframeAt(progress);
}

/// The shaped progress of [animation] looping over [cycleFrames] at [frame],
/// across a span wide enough to hold several cycles.
double _progress(Animation animation, int frame, int cycleFrames) => MotionRunner.progress(
  frame: frame,
  span: ResolvedSpan(0, cycleFrames * 6),
  ease: _curve(animation),
  fps: _fps,
  repeat: animation.repeat ?? const Repeat.forever(),
  cycleFrames: cycleFrames,
);

/// The largest one-frame change of [value] across the first cycle, the
/// yardstick the wrap step must not exceed.
double _maxInnerStep(double Function(int frame) value, int cycleFrames) {
  var maxStep = 0.0;
  for (var frame = 1; frame < cycleFrames; frame++) {
    maxStep = math.max(maxStep, (value(frame) - value(frame - 1)).abs());
  }
  return maxStep;
}

void main() {
  group('Ambient loop continuity (WI-16, §22)', () {
    test('float (unseeded) y is continuous across the wrap', () {
      final float = Animation.float();
      const cycle = 75; // 1/0.4 s at 30 fps.
      double y(int frame) => _keyframeAt(float, _progress(float, frame, cycle), cycle).y ?? 0;
      final inner = _maxInnerStep(y, cycle);
      final wrap = (y(cycle) - y(cycle - 1)).abs();
      expect(wrap, lessThanOrEqualTo(inner + 1e-9), reason: 'no jump at the float wrap');
    });

    test('float (seeded) y is continuous across the wrap', () {
      const noise = ValueNoise();
      const cycle = 75;
      const amp = 0.04;
      double y(int frame) => FloatEffect.offsetAt(
        frame: frame,
        cycleFrames: cycle,
        amplitude: amp,
        seed: 'leaf-7',
        noise: noise,
      );
      final inner = _maxInnerStep(y, cycle);
      final wrap = (y(cycle) - y(cycle - 1)).abs();
      expect(wrap, lessThanOrEqualTo(inner + 1e-9), reason: 'no jump at the seeded float wrap');
    });

    test('pulse scale is continuous across the wrap (yoyo)', () {
      final pulse = Animation.pulse();
      // 1.2 s period; the half-period tween is 18 frames, and yoyo makes the
      // full cycle 18 frames that the runner reverses on odd passes.
      const cycle = 18;
      double scale(int frame) =>
          _keyframeAt(pulse, _progress(pulse, frame, cycle), cycle).scale ?? 1;
      final inner = _maxInnerStep(scale, cycle);
      final wrap = (scale(cycle) - scale(cycle - 1)).abs();
      expect(wrap, lessThanOrEqualTo(inner + 1e-9), reason: 'no jump at the pulse yoyo turn');
    });

    test('spin rotation is continuous across the wrap', () {
      final spin = Animation.spin();
      const cycle = 120; // 4 s per turn at 30 fps.
      double turns(int frame) =>
          _keyframeAt(spin, _progress(spin, frame, cycle), cycle).rotation ?? 0;
      // Rotation runs 0 -> 1 turn then resets to 0: the wrap is a full turn,
      // which is visually continuous (0 and 1 turn are the same orientation).
      // Compare against the inner step modulo one full turn.
      final inner = _maxInnerStep(turns, cycle);
      final raw = (turns(cycle) - turns(cycle - 1)).abs();
      final wrap = (raw - raw.roundToDouble()).abs(); // distance to the nearest whole turn
      expect(wrap, lessThanOrEqualTo(inner + 1e-9), reason: 'spin wraps a whole turn (same pose)');
    });
  });
}
