import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/effects/bloom_effect.dart';
import 'package:fluvie/src/animation/effects/blur_effect.dart';
import 'package:fluvie/src/animation/effects/chromatic_effect.dart';
import 'package:fluvie/src/animation/effects/color_grade_effect.dart';
import 'package:fluvie/src/animation/effects/curves_effect.dart';
import 'package:fluvie/src/animation/effects/glitch_effect.dart';
import 'package:fluvie/src/animation/effects/grain_effect.dart';
import 'package:fluvie/src/animation/effects/lut_effect.dart';
import 'package:fluvie/src/animation/effects/parallax_effect.dart';
import 'package:fluvie/src/animation/effects/particles_effect.dart';
import 'package:fluvie/src/animation/effects/scanlines_effect.dart';
import 'package:fluvie/src/animation/effects/shader_effect.dart';
import 'package:fluvie/src/animation/effects/vignette_effect.dart';
import 'package:fluvie/src/animation/runtime/effect_layer.dart';
import 'package:fluvie/src/animation/runtime/effect_stack.dart';
import 'package:fluvie/src/core/color/tone_curve.dart';
import 'package:fluvie/src/core/edge.dart';
import 'package:fluvie/src/core/particles/particles.dart';
import 'package:fluvie/src/serialization/effect_builder.dart';
import 'package:fluvie/src/serialization/effect_spec.dart';

// fluvie:large-file-ok: one cohesive public facade — the named effects a
// `.effects([...])` stack takes, each a one-line forward to its implementation.

/// The effects a `.effects([...])` stack takes: the same thirteen surfaces the
/// spec's `effects` list names, spelled for Dart.
///
/// Every default here is the effect's own current value, so a stack that names
/// nothing renders exactly what it rendered before there were stacks.
///
/// An effect is either **transform-class** (it wraps the widget) or
/// **pixel-class** (it post-processes the result), and the stack composes
/// transform-first whatever order they were written in — the same discipline
/// `.animate([...])` already applies.
abstract final class Effect {
  /// Seeded monochrome film grain over the child, [amount] in `[0, 1]`.
  static EffectLayer grain({double amount = 0.2}) => EffectLayer.of(GrainEffect(amount));

  /// Darkened corners, [amount] in `[0, 1]`.
  static EffectLayer vignette({double amount = 0.4}) => EffectLayer.of(VignetteEffect(amount));

  /// Horizontal CRT lines every [spacing] pixels at [opacity].
  static EffectLayer scanlines({double spacing = 3, double opacity = 0.35}) =>
      EffectLayer.of(ScanlinesEffect(spacing: spacing, opacity: opacity));

  /// A red/blue channel split of [px] logical pixels.
  static EffectLayer chromatic({double px = 2}) => EffectLayer.of(ChromaticEffect(px));

  /// Gaussian blur of the element; zero is an exact no-op.
  static EffectLayer blur({double sigma = 4}) => EffectLayer.of(BlurEffect(sigma));

  /// An additive glow, [amount] in `[0, 1]`.
  static EffectLayer bloom({double amount = 0.4}) => EffectLayer.of(BloomEffect(amount));

  /// A colour grade; every parameter defaults to its neutral value, and the
  /// composition order (white balance, exposure, contrast, saturation) is
  /// the spec's, pinned in [ColorGradeEffect.matrixFor].
  static EffectLayer grade({
    double exposure = 0,
    double contrast = 1,
    double saturation = 1,
    double temperature = 0,
    double tint = 0,
    double intensity = 1,
  }) => EffectLayer.of(
    ColorGradeEffect(
      exposure: exposure,
      contrast: contrast,
      saturation: saturation,
      temperature: temperature,
      tint: tint,
      intensity: intensity,
    ),
  );

  /// Sliced band jitter biased toward [from]; [reverse] degrades instead of
  /// resolving.
  static EffectLayer glitch({String from = 'left', bool reverse = false, double intensity = 1}) =>
      EffectLayer.of(
        GlitchEffect(
          from: from == 'right' ? Edge.right : Edge.left,
          reverse: reverse,
          intensity: intensity,
        ),
      );

  /// Per-channel tone curves over the element, each defaulting to the
  /// identity; [intensity] mixes toward the untouched frame.
  static EffectLayer curves({
    ToneCurve master = ToneCurve.identity,
    ToneCurve red = ToneCurve.identity,
    ToneCurve green = ToneCurve.identity,
    ToneCurve blue = ToneCurve.identity,
    double intensity = 1,
  }) => EffectLayer.of(
    CurvesEffect(master: master, red: red, green: green, blue: blue, intensity: intensity),
  );

  /// A `.cube` 3D LUT over the element; [intensity] mixes toward the
  /// untouched frame.
  static EffectLayer lut({String asset = '', String? cube, double intensity = 1}) =>
      EffectLayer.of(LutEffect(asset: asset, cube: cube, intensity: intensity));

  /// A seeded particle field.
  static EffectLayer particles({Particles spec = const Particles.sparkle()}) =>
      EffectLayer.of(ParticlesEffect(spec));

  /// A fragment shader over the child, warmed from [asset].
  static EffectLayer shader({required String asset, Map<String, Object> uniforms = const {}}) =>
      EffectLayer.of(ShaderEffect(shaderName: asset, uniforms: uniforms));

  /// A depth-scaled drift with the scene.
  static EffectLayer parallax({double depth = 0.2}) => EffectLayer.of(ParallaxEffect(depth: depth));

  /// The effect [spec] declares, parameters and all.
  ///
  /// The spelling for an effect whose parameters change over time: the named
  /// factories above take plain numbers because that is what almost every
  /// stack wants, and a keyframed parameter says so through its own
  /// declaration rather than doubling every signature.
  static EffectLayer spec(EffectSpec spec) => layerOf(spec);
}

/// Wrapping a widget in an effect stack.
extension EffectsExtension on Widget {
  /// This widget under [effects], transform-class innermost and pixel-class
  /// outermost, list order preserved within a class.
  ///
  /// An empty list wraps nothing at all, so `.effects([])` costs exactly what
  /// writing nothing costs.
  Widget effects(List<EffectLayer> effects) {
    final ordered = <EffectLayer>[
      for (final layer in effects)
        if (!layer.isPixel) layer,
      for (final layer in effects)
        if (layer.isPixel) layer,
    ];
    if (ordered.isEmpty) return this;
    return EffectStack(effects: ordered, child: this);
  }
}
