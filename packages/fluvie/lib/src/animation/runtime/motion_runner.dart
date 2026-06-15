import 'dart:math' as math;

import 'package:flutter/animation.dart' show Curve;
import 'package:fluvie/src/core/repeat.dart';
import 'package:fluvie/src/core/spring_solver.dart';
import 'package:fluvie/src/core/timing.dart';
import 'package:fluvie/src/timing/resolver/trigger_resolver.dart';

/// The pure progress function of the animation system: frame in, shaped
/// progress out.
///
/// Determinism lives here — no clocks, no state, just arithmetic on the
/// frame number — so the same call always returns the same double.
abstract final class MotionRunner {
  /// The shaped progress of one animation at [frame].
  ///
  /// Clamping: `0` before `span.start`, exactly `1` at/after `span.end`
  /// (a zero-length span is already complete), otherwise linear
  /// `t = (frame − start) / (end − start)` shaped by [spring] (which wins)
  /// or [ease]. Springs evaluate `1 − SpringSolver.value(seconds)`
  /// un-clamped mid-flight — overshoot is the point — and are forced to
  /// exactly `1.0` once their cycle completes.
  ///
  /// With [repeat], the span becomes cycles of [cycleFrames] frames
  /// separated by [gapFrames]-frame gaps holding the just-reached endpoint;
  /// yoyo reverses the *linear* position of odd cycles before shaping, and
  /// `Repeat.times(n)` holds the n-th cycle's endpoint afterwards. The
  /// caller derives [cycleFrames] from the animation's effective duration;
  /// looping never widens the resolved span (the chaining contract).
  static double progress({
    required int frame,
    required ResolvedSpan span,
    required Curve ease,
    required int fps,
    Spring? spring,
    Repeat? repeat,
    int cycleFrames = 0,
    int gapFrames = 0,
  }) {
    assert(fps > 0, 'fps must be > 0');
    if (frame < span.start) return 0;
    final spanFrames = span.end - span.start;
    if (spanFrames <= 0) return 1;
    if (repeat == null) {
      if (frame >= span.end) return 1;
      final linear = (frame - span.start) / spanFrames;
      return _shape(linear, ease: ease, spring: spring, cycleFrames: spanFrames, fps: fps);
    }
    assert(cycleFrames > 0, 'a repeating animation needs cycleFrames > 0');
    assert(gapFrames >= 0, 'gapFrames must be >= 0');
    final period = cycleFrames + gapFrames;
    final local = frame - span.start;
    var cycle = local ~/ period;
    var position = local - cycle * period;
    final count = repeat.count;
    if (count != null && cycle >= count) {
      // Past the last cycle: hold its endpoint to the span end and beyond.
      cycle = count - 1;
      position = cycleFrames;
    }
    var linear = math.min(position, cycleFrames) / cycleFrames;
    if (repeat.yoyo && cycle.isOdd) linear = 1 - linear;
    return _shape(linear, ease: ease, spring: spring, cycleFrames: cycleFrames, fps: fps);
  }

  /// Shapes a linear cycle position: springs map it to seconds since the
  /// cycle start (exactly `1.0` once complete); tweens apply [ease].
  static double _shape(
    double linear, {
    required Curve ease,
    required Spring? spring,
    required int cycleFrames,
    required int fps,
  }) {
    if (spring != null) {
      if (linear >= 1) return 1;
      return 1 - SpringSolver(spring).value(linear * cycleFrames / fps);
    }
    return ease.transform(linear);
  }
}
