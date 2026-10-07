import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/animation_effect.dart';
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
import 'package:fluvie/src/animation/keyframed_number.dart';
import 'package:fluvie/src/animation/runtime/effect_layer.dart';
import 'package:fluvie/src/animation/runtime/effect_stack.dart';
import 'package:fluvie/src/core/color/tone_curve.dart';
import 'package:fluvie/src/core/edge.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/particles/particles.dart';
import 'package:fluvie/src/serialization/codecs/particles_codec.dart';
import 'package:fluvie/src/serialization/effect_spec.dart';

part 'effect_builder_curves.dart';

/// Wraps [child] in the effects [specs] declares, or returns it unchanged when
/// there are none to mount.
///
/// The stack composes by **class, then list order**: transform-class effects
/// innermost and pixel-class outermost, each group keeping the order it was
/// written in. That is the same transform-then-pixel discipline the animation
/// pipeline already applies to `.animate([...])`, so a stack reads the same
/// however it was typed and a spec-built tree matches a hand-written one.
///
/// A disabled effect mounts nothing and passes its child straight through. It
/// is not a hidden element — it is a layer the author turned off — so it must
/// not collapse the subtree the way `visible: false` does.
Widget buildEffectStack(List<EffectSpec> specs, Widget child) {
  final effects = <EffectLayer>[
    for (final spec in specs)
      if (spec.enabled && !spec.kind.isPixel) layerOf(spec),
    for (final spec in specs)
      if (spec.enabled && spec.kind.isPixel) layerOf(spec),
  ];
  if (effects.isEmpty) return child;
  return EffectStack(effects: effects, child: child);
}

/// [spec] as a stack layer: built once when nothing about it varies, read per
/// frame when something does. A disabled spec is a layer that mounts nothing,
/// so `Effect.spec` and the builder agree on what off means.
EffectLayer layerOf(EffectSpec spec) {
  if (!spec.enabled) return EffectLayer.of(const _NoEffect());
  return spec.varies
      ? EffectLayer(
          resolve: (frame) => buildEffect(spec, frame: frame),
          isPixel: spec.kind.isPixel,
        )
      : EffectLayer.of(buildEffect(spec));
}

/// What a disabled effect does: nothing, visibly and structurally.
final class _NoEffect implements AnimationEffect {
  const _NoEffect();

  @override
  Widget build(Widget child, double progress) => child;
}

/// The runtime effect [spec] declares, on its own defaults where the document
/// is silent.
AnimationEffect buildEffect(EffectSpec spec, {EffectFrame frame = _start}) => switch (spec.kind) {
  EffectSpecKind.grain => GrainEffect(spec.number('amount', frame: frame)),
  EffectSpecKind.vignette => VignetteEffect(spec.number('amount', frame: frame)),
  EffectSpecKind.scanlines => ScanlinesEffect(
    spacing: spec.number('spacing', frame: frame),
    opacity: spec.number('opacity', frame: frame),
  ),
  EffectSpecKind.chromatic => ChromaticEffect(spec.number('px', frame: frame)),
  EffectSpecKind.grade => ColorGradeEffect(
    exposure: spec.number('exposure', frame: frame),
    contrast: spec.number('contrast', frame: frame),
    saturation: spec.number('saturation', frame: frame),
    temperature: spec.number('temperature', frame: frame),
    tint: spec.number('tint', frame: frame),
    intensity: spec.number('intensity', frame: frame),
  ),
  EffectSpecKind.blur => BlurEffect(spec.number('sigma', frame: frame)),
  EffectSpecKind.bloom => BloomEffect(spec.number('amount', frame: frame)),
  EffectSpecKind.glitch => GlitchEffect(
    from: spec.text('from') == 'right' ? Edge.right : Edge.left,
    reverse: spec.flag('reverse'),
    intensity: spec.number('intensity', frame: frame),
  ),
  EffectSpecKind.particles => ParticlesEffect(
    spec.object('particles') == null
        ? const Particles.sparkle()
        : decodeParticles(spec.object('particles'), path: const ['effects', 'particles']),
  ),
  EffectSpecKind.shader =>
    (spec.text('asset') ?? '').isEmpty
        ? const _NoEffect()
        : ShaderEffect(
            shaderName: _narrowedAsset(spec.text('asset') ?? '', kind: 'shader'),
            uniforms: _uniforms(spec.object('uniforms')),
          ),
  EffectSpecKind.parallax => ParallaxEffect(depth: spec.number('depth', frame: frame)),
  EffectSpecKind.curves => _curves(spec, frame),
  // An absent asset is tolerated (the effect grades nothing until it is
  // named, which is how the editor adds-then-names); a present one is
  // narrowed like every asset the spec names.
  EffectSpecKind.lut => LutEffect(
    asset: switch (spec.text('asset') ?? '') {
      '' => '',
      final asset => _narrowedAsset(asset, kind: 'lut'),
    },
    cube: spec.text('cube'),
    intensity: spec.number('intensity', frame: frame),
  ),
};

/// The frame a still effect is built at: the element's first, where every
/// parameter is the number it is everywhere else.
const EffectFrame _start = (progress: 0, fps: 30, windowFrames: 0);

/// Refuses anything but a plain relative asset path — no absolute paths,
/// no `..`, no URL schemes — the same narrowing every spec-named asset
/// faces before it reaches a loader.
String _narrowedAsset(String raw, {required String kind}) {
  if (raw.isEmpty) {
    throw FluvieSpecError('A $kind needs an "asset" path string', path: const ['effects']);
  }
  final absolute = raw.startsWith('/') || raw.startsWith(r'\');
  final escapes = raw.split(RegExp(r'[/\\]')).contains('..');
  if (absolute || escapes || raw.contains(':')) {
    throw FluvieSpecError(
      'A $kind "asset" must be a plain relative asset path (no absolute '
      'paths, no "..", no URL schemes); got "$raw"',
      path: const ['effects'],
    );
  }
  return raw;
}

/// The author uniforms, coerced to the `Object` values the shader binds.
Map<String, Object> _uniforms(Map<String, Object?>? raw) => {
  if (raw != null)
    for (final entry in raw.entries)
      if (entry.value case final Object value) entry.key: value,
};
