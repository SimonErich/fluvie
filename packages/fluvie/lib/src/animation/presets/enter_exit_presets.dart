import 'dart:math' as math;

import 'package:flutter/painting.dart' show Alignment;
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/effects/mask_wipe_effect.dart';
import 'package:fluvie/src/animation/presets/preset_tail.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/core/edge.dart';
import 'package:fluvie/src/core/keyframe.dart';
import 'package:fluvie/src/core/timing.dart';
import 'package:fluvie/src/core/wipe_shape.dart';

/// Builds `Animation.fadeIn`: opacity `0` → natural, an enter.
Animation buildFadeIn(PresetTail tail) => _enter(const Keyframe(opacity: 0), tail);

/// Builds `Animation.fadeOut`: natural → opacity `0`, an exit.
Animation buildFadeOut(PresetTail tail) => _exit(const Keyframe(opacity: 0), tail);

/// Builds `Animation.slideIn`: one element-size off the [from] edge →
/// natural, an enter.
Animation buildSlideIn(Edge from, PresetTail tail) =>
    _enter(Keyframe(x: from.dx, y: from.dy), tail);

/// Builds `Animation.slideOut`: natural → one element-size off the [to]
/// edge, an exit.
Animation buildSlideOut(Edge to, PresetTail tail) => _exit(Keyframe(x: to.dx, y: to.dy), tail);

/// Builds `Animation.slideFadeIn`: transparent and one element-size off
/// the [from] edge → natural, an enter.
Animation buildSlideFadeIn(Edge from, PresetTail tail) =>
    _enter(Keyframe(opacity: 0, x: from.dx, y: from.dy), tail);

/// Builds `Animation.slideFadeOut`: natural → transparent and one
/// element-size off the [to] edge, an exit.
Animation buildSlideFadeOut(Edge to, PresetTail tail) =>
    _exit(Keyframe(opacity: 0, x: to.dx, y: to.dy), tail);

/// Builds `Animation.pop`: scale `0` → natural on the
/// overshoot-derived spring; an explicit tail spring wins.
Animation buildPop(double overshoot, PresetTail tail) =>
    _enter(const Keyframe(scale: 0), _withSpring(tail, tail.spring ?? _popSpring(overshoot)));

/// Builds `Animation.scaleIn`: scale [from] → natural on
/// [Spring.snappy]; an explicit tail spring wins.
Animation buildScaleIn(double from, PresetTail tail) =>
    _enter(Keyframe(scale: from), _withSpring(tail, tail.spring ?? Spring.snappy));

/// Builds `Animation.scaleOut`: natural → scale [to] on
/// [Spring.snappy]; an explicit tail spring wins.
Animation buildScaleOut(double to, PresetTail tail) =>
    _exit(Keyframe(scale: to), _withSpring(tail, tail.spring ?? Spring.snappy));

/// Builds `Animation.blurIn`: gaussian blur [sigma] → sharp,
/// blur-only (compose with `fadeIn` for blur+fade), an enter.
Animation buildBlurIn(double sigma, PresetTail tail) => _enter(Keyframe(blur: sigma), tail);

/// Builds `Animation.blurOut`: sharp → gaussian blur [sigma],
/// blur-only, an exit.
Animation buildBlurOut(double sigma, PresetTail tail) => _exit(Keyframe(blur: sigma), tail);

/// Builds `Animation.maskWipeIn`: a [shape] mask growing from [origin]
/// reveals the element, an enter (the `custom` default phase).
Animation buildMaskWipeIn(WipeShape shape, Alignment origin, PresetTail tail) => Animation.custom(
  MaskWipeEffect(shape: shape, origin: origin),
  duration: tail.duration,
  ease: tail.ease,
  spring: tail.spring,
  delay: tail.delay,
  at: tail.at,
  stagger: tail.stagger,
  repeat: tail.repeat,
  label: tail.label,
);

/// Builds `Animation.maskWipeOut`: the [shape] mask shrinks toward
/// [origin], hiding the element, an exit.
Animation buildMaskWipeOut(WipeShape shape, Alignment origin, PresetTail tail) => Animation.custom(
  MaskWipeEffect(shape: shape, origin: origin, reverse: true),
  phase: AnimationPhase.exit,
  duration: tail.duration,
  ease: tail.ease,
  spring: tail.spring,
  delay: tail.delay,
  at: tail.at,
  stagger: tail.stagger,
  repeat: tail.repeat,
  label: tail.label,
);

/// The closed form: with `o = overshoot − 1`, the damping ratio
/// `ζ = −ln(o)/√(π² + ln²(o))` makes the first spring peak overshoot by
/// exactly `o`; `damping = 2ζ√(stiffness·mass)` on the default 180/1 spring.
Spring _popSpring(double overshoot) {
  assert(
    overshoot > 1 && overshoot < 2,
    'pop overshoot is the peak scale and must lie in (1, 2) — 1.1 means 10% past the target',
  );
  final lnO = math.log(overshoot - 1);
  final zeta = -lnO / math.sqrt(math.pi * math.pi + lnO * lnO);
  // Stiffness and mass stay at the Spring defaults (180 and 1).
  return Spring(damping: 2 * zeta * math.sqrt(180.0 * 1.0));
}

Animation _enter(Keyframe from, PresetTail tail) => Animation.from(
  from,
  duration: tail.duration,
  ease: tail.ease,
  spring: tail.spring,
  delay: tail.delay,
  at: tail.at,
  stagger: tail.stagger,
  repeat: tail.repeat,
  label: tail.label,
);

Animation _exit(Keyframe to, PresetTail tail) => Animation.to(
  to,
  duration: tail.duration,
  ease: tail.ease,
  spring: tail.spring,
  delay: tail.delay,
  at: tail.at,
  stagger: tail.stagger,
  repeat: tail.repeat,
  label: tail.label,
);

PresetTail _withSpring(PresetTail tail, Spring spring) => (
  duration: tail.duration,
  ease: tail.ease,
  spring: spring,
  delay: tail.delay,
  at: tail.at,
  stagger: tail.stagger,
  repeat: tail.repeat,
  label: tail.label,
);
