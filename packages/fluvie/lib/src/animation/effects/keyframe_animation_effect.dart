import 'package:fluvie/src/animation/animation_effect.dart';
import 'package:fluvie/src/core/keyframe.dart';

/// An [AnimationEffect] whose visual state is a [Keyframe] — the class the
/// pipeline composes.
///
/// At a given frame, all keyframe-class animations on one element fold their
/// [keyframeAt] results into a single [Keyframe] (last writer wins per
/// field), applied by one render-safe widget stack closest to the child.
/// Non-keyframe effects only ever wrap; keyframe effects *merge*.
abstract interface class KeyframeAnimationEffect implements AnimationEffect {
  /// The keyframe this effect contributes at [progress].
  ///
  /// [progress] is already shaped (curve or spring); values outside `[0, 1]`
  /// extrapolate so spring overshoot reads naturally.
  Keyframe keyframeAt(double progress);
}
