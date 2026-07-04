import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/effect_kind.dart';
import 'package:fluvie/src/animation/effects/bloom_effect.dart';
import 'package:fluvie/src/animation/effects/chromatic_effect.dart';
import 'package:fluvie/src/animation/effects/glitch_effect.dart';
import 'package:fluvie/src/animation/effects/grain_effect.dart';
import 'package:fluvie/src/animation/effects/parallax_effect.dart';
import 'package:fluvie/src/animation/effects/particles_effect.dart';
import 'package:fluvie/src/animation/effects/scanlines_effect.dart';
import 'package:fluvie/src/animation/effects/shader_effect.dart';
import 'package:fluvie/src/animation/effects/vignette_effect.dart';
import 'package:fluvie/src/animation/presets/preset_tail.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/core/edge.dart';
import 'package:fluvie/src/core/particles/particles.dart';
import 'package:meta/meta.dart';

/// Builds `Animation.grain`: a pixel-class [GrainEffect] at [amount]
/// strength, wrapped as an `Animation.custom` so the transform-then-pixel
/// pipeline orders it outermost for free.
Animation buildGrain(double amount, PresetTail tail) => _pixel(GrainEffect(amount), tail);

/// Builds `Animation.vignette`: a pixel-class [VignetteEffect] darkening
/// the edges at [amount] strength.
Animation buildVignette(double amount, PresetTail tail) => _pixel(VignetteEffect(amount), tail);

/// Builds `Animation.scanlines`: a pixel-class [ScanlinesEffect] overlay
/// with the default spacing and opacity.
Animation buildScanlines(PresetTail tail) => _pixel(const ScanlinesEffect(), tail);

/// Builds `Animation.chromatic`: a pixel-class [ChromaticEffect] splitting
/// the channels by [px] logical pixels.
Animation buildChromatic(double px, PresetTail tail) => _pixel(ChromaticEffect(px), tail);

/// Builds `Animation.bloom`: a pixel-class [BloomEffect] glow at [amount]
/// strength.
Animation buildBloom(double amount, PresetTail tail) => _pixel(BloomEffect(amount), tail);

/// Builds `Animation.glitchIn`: a pixel-class [GlitchEffect] biased toward
/// [from] that resolves to the natural frame at progress `1`.
Animation buildGlitchIn(Edge from, PresetTail tail) => _pixel(GlitchEffect(from: from), tail);

/// Builds `Animation.glitchOut`: the same seeded tear growing instead of
/// resolving, biased toward [to] — an exit.
Animation buildGlitchOut(Edge to, PresetTail tail) =>
    _pixel(GlitchEffect(from: to, reverse: true), tail, phase: AnimationPhase.exit);

/// Builds `Animation.particles`: a pixel-class [ParticlesEffect] laying the
/// [spec]'s seeded field over the element — `progress` scrolls the field.
Animation buildParticles(Particles spec, PresetTail tail) => _pixel(ParticlesEffect(spec), tail);

/// Builds `Animation.shader`: a pixel-class, **experimental**
/// [ShaderEffect] painting the fragment shader at [asset] over the element,
/// with author [uniforms] bound after the built-in `resolution`/`progress`
/// slots. The program is warmed by the render shell's pre-load pass before
/// frame 0; until then the effect carries only the asset name and asserts the
/// program is warm before paint.
@experimental
Animation buildShader(String asset, Map<String, Object> uniforms, PresetTail tail) =>
    _pixel(ShaderEffect(shaderName: asset, uniforms: uniforms), tail);

/// Builds `Animation.parallax`: a transform-class [ParallaxEffect]
/// drifting the element by [depth] across the scene. Wrapped as an
/// `Animation.custom` so it rides the unified pipeline, but it reads the scene
/// clock itself, so the tail's timing only positions when the drift is live.
Animation buildParallax(double depth, PresetTail tail) => Animation.custom(
  ParallaxEffect(depth: depth),
  duration: tail.duration,
  ease: tail.ease,
  spring: tail.spring,
  delay: tail.delay,
  at: tail.at,
  stagger: tail.stagger,
  repeat: tail.repeat,
  label: tail.label,
);

/// Wraps a pixel effect as an `Animation.custom`, forwarding the common tail —
/// the one-line delegation pattern shared by every pixel preset.
Animation _pixel(PixelAnimationEffect effect, PresetTail tail, {AnimationPhase? phase}) =>
    Animation.custom(
      effect,
      phase: phase,
      duration: tail.duration,
      ease: tail.ease,
      spring: tail.spring,
      delay: tail.delay,
      at: tail.at,
      stagger: tail.stagger,
      repeat: tail.repeat,
      label: tail.label,
    );
