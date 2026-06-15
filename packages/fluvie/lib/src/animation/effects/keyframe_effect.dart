import 'package:flutter/widgets.dart' show Widget;
import 'package:fluvie/src/animation/effects/keyframe_animation_effect.dart';
import 'package:fluvie/src/animation/effects/keyframe_applier.dart';
import 'package:fluvie/src/core/keyframe.dart';

/// The two-point keyframe effect behind `Animation.from`, `.to`, and
/// `.fromTo`: lerps [from] toward [to] as progress runs `0 → 1`.
///
/// Null fields stay null through [Keyframe.lerp] when both ends leave them
/// unset (the element keeps its natural value), and progress outside `[0, 1]`
/// extrapolates, so spring overshoot carries through to the keyframe.
final class KeyframeEffect implements KeyframeAnimationEffect {
  /// Creates an effect animating [from] toward [to].
  const KeyframeEffect({required this.from, required this.to});

  /// The keyframe at progress `0`.
  final Keyframe from;

  /// The keyframe at progress `1`.
  final Keyframe to;

  @override
  Keyframe keyframeAt(double progress) => Keyframe.lerp(from, to, progress);

  @override
  Widget build(Widget child, double progress) => applyKeyframe(keyframeAt(progress), child);

  @override
  String toString() => 'KeyframeEffect(from: $from, to: $to)';
}
