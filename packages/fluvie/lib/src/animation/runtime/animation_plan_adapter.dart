/// @docImport 'package:fluvie/src/timing/placement/effective_duration.dart';
/// @docImport 'package:fluvie/src/timing/resolver/composition_resolver.dart';
library;

import 'package:flutter/animation.dart' show Curve;
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/timing/plan/animation_plan.dart';

/// Strips [animation] down to the pure-data [AnimationPlan] the timing
/// resolver consumes — the bridge both local resolution and the composition
/// plan builder share, so the widget and plan views of one animation can never
/// drift apart.
///
/// The three nullable timing fields collapse to the plan's single `timing`
/// exactly as `Animation.timing` presents them: spring wins,
/// an explicit duration becomes a `Tween`, all-unset stays `null` for the
/// merged [Defaults] to fill in.
AnimationPlan toAnimationPlan(Animation animation) => AnimationPlan(
  phase: animation.phase,
  timing: animation.timing,
  delay: animation.delay,
  at: animation.at,
  stagger: animation.stagger,
  repeat: animation.repeat,
  label: animation.label,
);

/// Rebuilding a Flutter widget may recreate its animations without changing
/// the timing plan. Visual effects can change independently of that plan.
bool sameAnimationTiming(List<Animation> a, List<Animation> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    final left = toAnimationPlan(a[i]);
    final right = toAnimationPlan(b[i]);
    if (left.phase != right.phase ||
        left.timing != right.timing ||
        left.delay != right.delay ||
        left.at != right.at ||
        left.stagger != right.stagger ||
        left.repeat != right.repeat) {
      return false;
    }
  }
  return true;
}

/// The curve shaping [animation]'s progress at render time: its own `ease`
/// when declared, else the [merged] cascade's, else [Ease.smooth].
///
/// The last arm only fires when [merged] skipped [mergeDefaultsChain] (whose
/// cascade ends in the package defaults); it keeps this function total so the
/// runner never needs a nullable curve.
Curve effectiveCurve(Animation animation, Defaults merged) =>
    animation.ease ?? merged.ease ?? Ease.smooth;
