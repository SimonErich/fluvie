import 'package:flutter/painting.dart' show Color;
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/effects/gradient_shift_effect.dart';
import 'package:fluvie/src/animation/presets/preset_tail.dart';

/// Builds `Animation.gradientShift`: a transform-class
/// [GradientShiftEffect] publishing progress and [to] through a scope the
/// gradient-capable backgrounds consume — no `Keyframe` change, so the shift
/// rides the existing pipeline channel and composes with triggers, anchors,
/// and the `Defaults` cascade for free.
///
/// The expansion is `Animation.custom(GradientShiftEffect(to), …)`, an enter
/// by default (the rule for `custom`): start-anchored, so
/// `delay: 0.1.relative, duration: 0.3.relative` spans 1 s → 4 s and
/// `Trigger.after` on its anchor fires when the shift completes.
Animation buildGradientShift(List<Color> to, PresetTail tail) => Animation.custom(
  GradientShiftEffect(to),
  duration: tail.duration,
  ease: tail.ease,
  spring: tail.spring,
  delay: tail.delay,
  at: tail.at,
  stagger: tail.stagger,
  repeat: tail.repeat,
  label: tail.label,
);
