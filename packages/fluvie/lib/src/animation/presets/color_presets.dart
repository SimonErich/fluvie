import 'package:flutter/painting.dart' show Color;
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/presets/preset_tail.dart';
import 'package:fluvie/src/core/keyframe.dart';

/// Builds `Animation.color`: natural → `Keyframe(color: to)`, pure
/// preset data — the per-frame composed keyframe carries the lerped color and
/// color-capable elements consume it via `KeyframeScope` (`Background.color`
/// paints it).
///
/// Gradient shifting is its own preset (`gradient_presets.dart`); the
/// related `glitchIn` and pixel presets (grain, vignette, scanlines,
/// chromatic, bloom, particles, shader) live in the pixel-effect pipeline.
Animation buildColor(Color to, PresetTail tail) => Animation.to(
  Keyframe(color: to),
  duration: tail.duration,
  ease: tail.ease,
  spring: tail.spring,
  delay: tail.delay,
  at: tail.at,
  stagger: tail.stagger,
  repeat: tail.repeat,
  label: tail.label,
);
