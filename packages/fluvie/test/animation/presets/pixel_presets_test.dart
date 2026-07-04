import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/effect_kind.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/animation/effects/bloom_effect.dart';
import 'package:fluvie/src/animation/effects/chromatic_effect.dart';
import 'package:fluvie/src/animation/effects/glitch_effect.dart';
import 'package:fluvie/src/animation/effects/grain_effect.dart';
import 'package:fluvie/src/animation/effects/parallax_effect.dart';
import 'package:fluvie/src/animation/effects/particles_effect.dart';
import 'package:fluvie/src/animation/effects/scanlines_effect.dart';
import 'package:fluvie/src/animation/effects/shader_effect.dart';
import 'package:fluvie/src/animation/effects/vignette_effect.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/edge.dart';
import 'package:fluvie/src/core/particles/particles.dart';
import 'package:fluvie/src/core/repeat.dart';
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/trigger.dart';

void main() {
  group('Animation pixel presets (WI-6, D4/D5)', () {
    test('grain builds a pixel-classified GrainEffect carrying its amount', () {
      final a = Animation.grain(0.3);
      expect(a.effect, isA<GrainEffect>());
      expect((a.effect as GrainEffect).amount, 0.3);
      expect(effectKindOf(a.effect), EffectKind.pixel);
    });

    test('vignette builds a pixel-classified VignetteEffect', () {
      final a = Animation.vignette(0.4);
      expect(a.effect, isA<VignetteEffect>());
      expect((a.effect as VignetteEffect).amount, 0.4);
      expect(effectKindOf(a.effect), EffectKind.pixel);
    });

    test('scanlines builds a pixel-classified ScanlinesEffect with no required arg', () {
      final a = Animation.scanlines();
      expect(a.effect, isA<ScanlinesEffect>());
      expect(effectKindOf(a.effect), EffectKind.pixel);
    });

    test('chromatic builds a pixel-classified ChromaticEffect carrying px', () {
      final a = Animation.chromatic(2);
      expect(a.effect, isA<ChromaticEffect>());
      expect((a.effect as ChromaticEffect).px, 2);
      expect(effectKindOf(a.effect), EffectKind.pixel);
    });

    test('bloom builds a pixel-classified BloomEffect', () {
      final a = Animation.bloom(0.5);
      expect(a.effect, isA<BloomEffect>());
      expect((a.effect as BloomEffect).amount, 0.5);
      expect(effectKindOf(a.effect), EffectKind.pixel);
    });

    test('glitchIn builds a pixel-classified GlitchEffect carrying from', () {
      final a = Animation.glitchIn(from: Edge.right);
      expect(a.effect, isA<GlitchEffect>());
      expect((a.effect as GlitchEffect).from, Edge.right);
      expect(effectKindOf(a.effect), EffectKind.pixel);
    });

    test('glitchOut is the reversed tear biased toward Edge.right — an exit', () {
      final out = Animation.glitchOut();
      final effect = out.effect as GlitchEffect;
      expect(effect.from, Edge.right);
      expect(effect.reverse, isTrue);
      expect(out.phase, AnimationPhase.exit);
    });

    test('glitchIn defaults the slice direction to Edge.left', () {
      expect((Animation.glitchIn().effect as GlitchEffect).from, Edge.left);
    });

    test('particles builds a pixel-classified ParticlesEffect carrying its spec', () {
      const spec = Particles.confetti(count: 12, seed: 'p');
      final a = Animation.particles(spec);
      expect(a.effect, isA<ParticlesEffect>());
      expect((a.effect as ParticlesEffect).spec, spec);
      expect(effectKindOf(a.effect), EffectKind.pixel);
    });

    test('parallax builds a transform-classified ParallaxEffect carrying its depth', () {
      final a = Animation.parallax(depth: 0.5);
      expect(a.effect, isA<ParallaxEffect>());
      expect((a.effect as ParallaxEffect).depth, 0.5);
      expect(effectKindOf(a.effect), EffectKind.transform);
    });

    test('parallax defaults its depth to 0.2', () {
      expect((Animation.parallax().effect as ParallaxEffect).depth, 0.2);
    });

    test('shader builds a pixel-classified ShaderEffect carrying its asset and uniforms', () {
      final a = Animation.shader('shaders/ripple.frag', uniforms: const {'strength': 0.5});
      expect(a.effect, isA<ShaderEffect>());
      expect((a.effect as ShaderEffect).shaderName, 'shaders/ripple.frag');
      expect((a.effect as ShaderEffect).uniforms, const {'strength': 0.5});
      expect(effectKindOf(a.effect), EffectKind.pixel);
    });

    test('shader defaults its uniforms to empty', () {
      expect((Animation.shader('shaders/ripple.frag').effect as ShaderEffect).uniforms, isEmpty);
    });

    test('every pixel preset forwards the common tail verbatim', () {
      final a = Animation.grain(
        0.3,
        duration: const Time.frames(20),
        ease: Ease.snappy,
        delay: const Time.frames(4),
        at: Trigger.sceneEnd,
        stagger: const Stagger.each(Time.frames(2)),
        repeat: const Repeat.times(2),
        label: 'g',
      );
      expect(a.duration, const Time.frames(20));
      expect(a.ease, Ease.snappy);
      expect(a.delay, const Time.frames(4));
      expect(a.at, Trigger.sceneEnd);
      expect(a.stagger, const Stagger.each(Time.frames(2)));
      expect(a.repeat, const Repeat.times(2));
      expect(a.label, 'g');
    });
  });
}
