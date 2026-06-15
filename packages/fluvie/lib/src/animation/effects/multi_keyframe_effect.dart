import 'package:flutter/animation.dart' show Curve;
import 'package:flutter/widgets.dart' show Widget;
import 'package:fluvie/src/animation/effects/keyframe_animation_effect.dart';
import 'package:fluvie/src/animation/effects/keyframe_applier.dart';
import 'package:fluvie/src/core/keyframe.dart';
import 'package:fluvie/src/core/time.dart';

/// The multi-stop effect behind `Animation.keyframes`: progress travels
/// through [stops] segment by segment.
///
/// Stops are evenly spaced by default. Explicit positions come in two parts:
/// the raw [at] times declared at the call site, and the `stopFractions` the
/// animation pipeline resolves them into (it knows the span and fps) and
/// passes to [keyframeAt] per frame. [easings] shape each segment locally —
/// the animation-level curve has already shaped global progress by the time
/// it arrives here.
final class MultiKeyframeEffect implements KeyframeAnimationEffect {
  /// Creates a multi-stop effect over [stops], optionally easing each
  /// segment with [easings] and positioning stops at [at].
  ///
  /// Structural rules — at least two stops, one easing per segment, one time
  /// per stop — are asserted on first use ([keyframeAt]/[build]) because
  /// list lengths cannot be checked in a const constructor.
  const MultiKeyframeEffect(this.stops, {this.easings, this.at});

  /// The keyframes progress travels through, in order.
  final List<Keyframe> stops;

  /// Per-segment curves (`easings[i]` shapes the segment from `stops[i]` to
  /// `stops[i + 1]`); `null` means every segment lerps linearly.
  final List<Curve>? easings;

  /// The declared stop positions as raw [Time]s, or `null` for even spacing.
  ///
  /// Times stay symbolic here — the pipeline resolves them against the
  /// animation's span into the `stopFractions` of [keyframeAt].
  final List<Time>? at;

  /// The composed keyframe at [progress], with stops at [stopFractions]
  /// (resolved `0 → 1` positions) or evenly spaced when `null`.
  ///
  /// Progress outside the first/last stop holds that boundary stop, so
  /// multi-stop sequences never extrapolate.
  @override
  Keyframe keyframeAt(double progress, {List<double>? stopFractions}) {
    _assertValid();
    assert(
      stopFractions == null || stopFractions.length == stops.length,
      'stopFractions must have exactly one fraction per stop',
    );
    assert(
      stopFractions == null || _strictlyIncreasing01(stopFractions),
      'stopFractions must increase strictly within 0..1',
    );
    final count = stops.length;
    double fractionAt(int i) => stopFractions == null ? i / (count - 1) : stopFractions[i];
    if (progress <= fractionAt(0)) return stops.first;
    if (progress >= fractionAt(count - 1)) return stops.last;
    var segment = 0;
    while (progress > fractionAt(segment + 1)) {
      segment += 1;
    }
    final from = fractionAt(segment);
    final to = fractionAt(segment + 1);
    final local = (progress - from) / (to - from);
    final shaped = easings?[segment].transform(local) ?? local;
    return Keyframe.lerp(stops[segment], stops[segment + 1], shaped);
  }

  @override
  Widget build(Widget child, double progress) => applyKeyframe(keyframeAt(progress), child);

  void _assertValid() {
    assert(stops.length >= 2, 'MultiKeyframeEffect needs at least two stops');
    assert(
      easings == null || easings!.length == stops.length - 1,
      'easings must have stops.length - 1 entries (one per segment)',
    );
    assert(at == null || at!.length == stops.length, 'at must have exactly one Time per stop');
  }

  static bool _strictlyIncreasing01(List<double> fractions) {
    for (var i = 0; i < fractions.length; i++) {
      if (fractions[i] < 0 || fractions[i] > 1) return false;
      if (i > 0 && fractions[i] <= fractions[i - 1]) return false;
    }
    return true;
  }

  @override
  String toString() => 'MultiKeyframeEffect(${stops.length} stops)';
}
