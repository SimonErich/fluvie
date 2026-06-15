import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/effects/bloom_effect.dart';
import 'package:fluvie/src/animation/effects/chromatic_effect.dart';
import 'package:fluvie/src/animation/effects/float_effect.dart';
import 'package:fluvie/src/animation/effects/glitch_effect.dart';
import 'package:fluvie/src/animation/effects/gradient_shift_effect.dart';
import 'package:fluvie/src/animation/effects/grain_effect.dart';
import 'package:fluvie/src/animation/effects/keyframe_effect.dart';
import 'package:fluvie/src/animation/effects/mask_wipe_effect.dart';
import 'package:fluvie/src/animation/effects/parallax_effect.dart';
import 'package:fluvie/src/animation/effects/particles_effect.dart';
import 'package:fluvie/src/animation/effects/path_effect.dart';
import 'package:fluvie/src/animation/effects/reactive_effect.dart';
import 'package:fluvie/src/animation/effects/scanlines_effect.dart';
import 'package:fluvie/src/animation/effects/shader_effect.dart';
import 'package:fluvie/src/animation/effects/vignette_effect.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/audio_band.dart';
import 'package:fluvie/src/core/keyframe.dart';
import 'package:fluvie/src/core/particles/particles.dart';
import 'package:fluvie/src/core/wipe_shape.dart';

/// The effect `toString()` diagnostics are public debug surfaces, so each one
/// must name the fields a developer needs to read off the inspector / a log.
/// These pin that contract (and cover the otherwise-untouched debug arms).
void main() {
  group('effect toString diagnostics name their state', () {
    test('BloomEffect', () {
      expect(const BloomEffect(0.5).toString(), 'BloomEffect(amount: 0.5)');
    });

    test('ChromaticEffect', () {
      expect(const ChromaticEffect(4).toString(), contains('px: 4'));
    });

    test('FloatEffect', () {
      final s = const FloatEffect(seed: 'wave', amplitude: 0.1, frequency: 0.5).toString();
      expect(s, contains('amplitude: 0.1'));
      expect(s, contains('frequency: 0.5'));
      expect(s, contains('seed: wave'));
    });

    test('GlitchEffect names its origin edge', () {
      expect(const GlitchEffect().toString(), contains('GlitchEffect(from: '));
    });

    test('GradientShiftEffect', () {
      const to = [Color(0xFF000000), Color(0xFFFFFFFF)];
      expect(const GradientShiftEffect(to).toString(), startsWith('GradientShiftEffect(to: '));
    });

    test('GrainEffect', () {
      expect(const GrainEffect(0.3).toString(), 'GrainEffect(amount: 0.3)');
    });

    test('KeyframeEffect names its endpoints', () {
      const effect = KeyframeEffect(from: Keyframe(opacity: 0), to: Keyframe(opacity: 1));
      expect(effect.toString(), startsWith('KeyframeEffect(from: '));
      expect(effect.toString(), contains('to: '));
    });

    testWidgets('KeyframeEffect.build wraps the child with the lerped keyframe', (tester) async {
      const effect = KeyframeEffect(from: Keyframe(opacity: 0), to: Keyframe(opacity: 1));
      const child = SizedBox(key: Key('kf-child'), width: 4, height: 4);
      await tester.pumpWidget(
        Directionality(textDirection: TextDirection.ltr, child: effect.build(child, 0.5)),
      );
      // The child survives the keyframe wrap, and an Opacity carries the 0.5 lerp.
      expect(find.byKey(const Key('kf-child')), findsOneWidget);
      final opacity = tester.widget<Opacity>(find.byType(Opacity).first);
      expect(opacity.opacity, closeTo(0.5, 1e-9));
    });

    test('MaskWipeEffect names the shape and origin', () {
      const s = MaskWipeEffect();
      expect(s.toString(), contains(WipeShape.circle.name));
      expect(s.toString(), contains('origin: '));
    });

    test('ParallaxEffect', () {
      expect(const ParallaxEffect(depth: 0.5).toString(), 'ParallaxEffect(depth: 0.5)');
    });

    test('ParticlesEffect wraps its spec', () {
      final s = const ParticlesEffect(Particles.confetti(seed: 'win')).toString();
      expect(s, startsWith('ParticlesEffect('));
      expect(s, contains('confetti'));
    });

    test('PathEffect names whether it orients', () {
      expect(PathEffect(Path(), orient: false).toString(), 'PathEffect(orient: false)');
    });

    test('ReactiveEffect names its mode, band, and gain', () {
      final s = const ReactiveEffect(
        mode: ReactiveMode.scaleY,
        band: AudioBand.bass,
        gain: 1.5,
      ).toString();
      expect(s, contains('scaleY'));
      expect(s, contains('band: bass'));
      expect(s, contains('gain: 1.5'));
    });

    test('ScanlinesEffect', () {
      final s = const ScanlinesEffect(spacing: 4, opacity: 0.5).toString();
      expect(s, contains('spacing: 4'));
      expect(s, contains('opacity: 0.5'));
    });

    test('ShaderEffect names its shader asset', () {
      expect(
        ShaderEffect(shaderName: 'shaders/wave.frag').toString(),
        'ShaderEffect(shader: shaders/wave.frag)',
      );
    });

    test('VignetteEffect', () {
      expect(const VignetteEffect(0.4).toString(), 'VignetteEffect(amount: 0.4)');
    });

    test('a tracked reactive effect still names its mode', () {
      final beat = Anchor('beat');
      final s = ReactiveEffect(
        mode: ReactiveMode.pulse,
        band: AudioBand.mid,
        track: beat,
      ).toString();
      expect(s, contains('pulse'));
    });
  });
}
