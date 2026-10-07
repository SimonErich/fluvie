import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart'
    show Animation, AnimationPhase, AudioBand, ParticleKind, Particles, knownAnimationPresets;
import 'package:fluvie/src/animation/effects/bloom_effect.dart';
import 'package:fluvie/src/animation/effects/chromatic_effect.dart';
import 'package:fluvie/src/animation/effects/gradient_shift_effect.dart';
import 'package:fluvie/src/animation/effects/keyframe_effect.dart';
import 'package:fluvie/src/animation/effects/parallax_effect.dart';
import 'package:fluvie/src/animation/effects/particles_effect.dart';
import 'package:fluvie/src/animation/effects/path_effect.dart';
import 'package:fluvie/src/animation/effects/reactive_effect.dart';
import 'package:fluvie/src/animation/effects/scanlines_effect.dart';
import 'package:fluvie/src/animation/effects/shader_effect.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/serialization/anchor_table.dart';
import 'package:fluvie/src/serialization/animation_builder.dart';
import 'package:fluvie/src/serialization/animation_spec.dart';
import 'package:fluvie/src/serialization/codecs/particles_codec.dart';

/// Parses one animation node, checks the round-trip, and builds it through the
/// given (or a fresh) anchor table.
Animation _build(Map<String, Object?> json, [AnchorTable? anchors]) {
  final table = anchors ?? AnchorTable();
  final spec = AnimationSpec.fromJson(json, table);
  expect(spec.toJson(), json, reason: 'the codec round-trip is identity');
  return buildAnimation(spec, table);
}

void main() {
  test('the wave-2 tranche joins the preset table', () {
    expect(
      knownAnimationPresets,
      containsAll([
        'color',
        'gradientShift',
        'scanlines',
        'chromatic',
        'bloom',
        'parallax',
        'particles',
        'shader',
        'scaleY',
        'along',
      ]),
    );
  });

  group('color and gradient data', () {
    test('color decodes its required target color', () {
      final animation = _build({'preset': 'color', 'to': '#FFD166', 'duration': '20f'});
      final effect = animation.effect as KeyframeEffect;
      expect(effect.to.color, const Color(0xFFFFD166));
    });

    test('color without a target fails', () {
      expect(() => _build({'preset': 'color'}), throwsA(isA<FluvieSpecError>()));
    });

    test('gradientShift decodes its color list', () {
      final animation = _build({
        'preset': 'gradientShift',
        'to': ['#101018', '#3C1E5A'],
      });
      final effect = animation.effect as GradientShiftEffect;
      expect(effect.to, const [Color(0xFF101018), Color(0xFF3C1E5A)]);
    });

    test('gradientShift rejects a non-list target', () {
      expect(
        () => _build({'preset': 'gradientShift', 'to': '#101018'}),
        throwsA(isA<FluvieSpecError>()),
      );
    });
  });

  group('pixel post-effects', () {
    test('scanlines takes no arguments', () {
      expect(_build({'preset': 'scanlines'}).effect, isA<ScanlinesEffect>());
    });

    test('chromatic reads px (defaulting to 0)', () {
      final effect = _build({'preset': 'chromatic', 'px': 2}).effect as ChromaticEffect;
      expect(effect.px, 2);
      expect((_build({'preset': 'chromatic'}).effect as ChromaticEffect).px, 0);
    });

    test('bloom reads amount (defaulting to 0)', () {
      final effect = _build({'preset': 'bloom', 'amount': 0.4}).effect as BloomEffect;
      expect(effect.amount, 0.4);
      expect((_build({'preset': 'bloom'}).effect as BloomEffect).amount, 0);
    });

    test('parallax reads depth (defaulting to 0.2)', () {
      final effect = _build({'preset': 'parallax', 'depth': 0.35}).effect as ParallaxEffect;
      expect(effect.depth, 0.35);
      expect((_build({'preset': 'parallax'}).effect as ParallaxEffect).depth, 0.2);
    });
  });

  group('particles', () {
    test('builds the field from a kind plus overrides', () {
      final animation = _build({
        'preset': 'particles',
        'spec': {'kind': 'confetti', 'count': 40, 'seed': 'launch'},
      });
      final effect = animation.effect as ParticlesEffect;
      expect(effect.spec, const Particles.confetti(count: 40, seed: 'launch'));
    });

    test('per-kind defaults fill every omitted field', () {
      final snow = decodeParticles({'kind': 'snow'});
      expect(snow, const Particles.snow());
      final sparkle = decodeParticles({
        'kind': 'sparkle',
        'palette': ['#FFFFFF'],
        'minSize': 2,
        'maxSize': 5,
        'fallSpeed': 0.1,
        'drift': 0.2,
        'spinSpeed': 1,
      });
      expect(sparkle.kind, ParticleKind.sparkle);
      expect(sparkle.palette, const [Color(0xFFFFFFFF)]);
      expect(sparkle.minSize, 2);
      expect(sparkle.maxSize, 5);
      expect(sparkle.fallSpeed, 0.1);
      expect(sparkle.drift, 0.2);
      expect(sparkle.spinSpeed, 1);
      expect(sparkle.count, const Particles.sparkle().count);
    });

    test('a malformed spec fails with a located error', () {
      expect(() => decodeParticles('confetti'), throwsA(isA<FluvieSpecError>()));
      expect(() => decodeParticles({'kind': 'plasma'}), throwsA(isA<FluvieSpecError>()));
      expect(
        () => decodeParticles({'kind': 'snow', 'count': 'many'}),
        throwsA(isA<FluvieSpecError>()),
      );
      expect(
        () => decodeParticles({'kind': 'snow', 'seed': 7}),
        throwsA(isA<FluvieSpecError>()),
      );
      expect(
        () => decodeParticles({'kind': 'snow', 'palette': '#FFFFFF'}),
        throwsA(isA<FluvieSpecError>()),
      );
      expect(
        () => decodeParticles({'kind': 'snow', 'minSize': 'big'}),
        throwsA(isA<FluvieSpecError>()),
      );
    });
  });

  group('shader', () {
    test('decodes the asset and its numeric uniforms', () {
      final animation = _build({
        'preset': 'shader',
        'asset': 'shaders/ripple.frag',
        'uniforms': {'speed': 2},
      });
      final effect = animation.effect as ShaderEffect;
      expect(effect.shaderName, 'shaders/ripple.frag');
      expect(effect.uniforms, {'speed': 2});
    });

    test('uniforms default to empty', () {
      final effect = _build({'preset': 'shader', 'asset': 'a.frag'}).effect as ShaderEffect;
      expect(effect.uniforms, isEmpty);
    });

    test('rejects an asset that is not a plain relative path', () {
      for (final asset in [
        '/etc/passwd.frag',
        '../secrets.frag',
        'shaders/../../escape.frag',
        r'shaders\..\escape.frag',
        'https://evil.example/x.frag',
        'file:x.frag',
        '',
        7,
        null,
      ]) {
        expect(
          () => _build({'preset': 'shader', 'asset': ?asset}),
          throwsA(isA<FluvieSpecError>()),
          reason: '"$asset" must be rejected',
        );
      }
    });

    test('rejects a non-numeric uniform value', () {
      expect(
        () => _build({
          'preset': 'shader',
          'asset': 'a.frag',
          'uniforms': {'speed': 'fast'},
        }),
        throwsA(isA<FluvieSpecError>()),
      );
      expect(
        () => _build({'preset': 'shader', 'asset': 'a.frag', 'uniforms': 'none'}),
        throwsA(isA<FluvieSpecError>()),
      );
    });
  });

  group('reactive presets', () {
    test('scaleY reads the band, gain, and track anchor identity', () {
      final anchors = AnchorTable();
      final animation = _build({
        'preset': 'scaleY',
        'on': 'mid',
        'gain': 1.5,
        'track': 'music',
      }, anchors);
      final effect = animation.effect as ReactiveEffect;
      expect(effect.mode, ReactiveMode.scaleY);
      expect(effect.band, AudioBand.mid);
      expect(effect.gain, 1.5);
      expect(effect.track, same(anchors.resolve('music')));
    });

    test('scaleY defaults gain to 1 and track to the master mix', () {
      final effect = _build({'preset': 'scaleY', 'on': 'bass'}).effect as ReactiveEffect;
      expect(effect.gain, 1.0);
      expect(effect.track, isNull);
    });

    test('scaleY without a band fails', () {
      expect(() => _build({'preset': 'scaleY'}), throwsA(isA<FluvieSpecError>()));
    });

    test('a non-string track fails instead of being dropped', () {
      expect(
        () => _build({'preset': 'scaleY', 'on': 'bass', 'track': 7}),
        throwsA(isA<FluvieSpecError>()),
      );
    });

    test('pulse with a band becomes the reactive pulse', () {
      final anchors = AnchorTable();
      final animation = _build({
        'preset': 'pulse',
        'on': 'bass',
        'gain': 1.4,
        'track': 'music',
      }, anchors);
      final effect = animation.effect as ReactiveEffect;
      expect(effect.mode, ReactiveMode.pulse);
      expect(effect.band, AudioBand.bass);
      expect(effect.gain, 1.4);
      expect(effect.track, same(anchors.resolve('music')));
    });

    test('pulse without a band stays the sine pulse', () {
      final animation = _build({'preset': 'pulse', 'min': 0.9, 'max': 1.1});
      expect(animation.effect, isNot(isA<ReactiveEffect>()));
    });
  });

  group('along', () {
    test('follows the SVG path and orients by default', () {
      final animation = _build({'preset': 'along', 'path': 'M 0 0 L 100 50'});
      final effect = animation.effect as PathEffect;
      expect(effect.orient, isTrue);
      expect(animation.phase, AnimationPhase.enter);
    });

    test('orient and phase are honored', () {
      final animation = _build({
        'preset': 'along',
        'path': 'M 0 0 C 40 -60 120 -60 160 0',
        'orient': false,
        'phase': 'during',
      });
      expect((animation.effect as PathEffect).orient, isFalse);
      expect(animation.phase, AnimationPhase.during);
    });

    test('a bad path or phase fails with a located error', () {
      expect(() => _build({'preset': 'along'}), throwsA(isA<FluvieSpecError>()));
      expect(
        () => _build({'preset': 'along', 'path': 'W 1 2'}),
        throwsA(isA<FluvieSpecError>()),
      );
      expect(
        () => _build({'preset': 'along', 'path': 'M 0 0', 'phase': 'sideways'}),
        throwsA(isA<FluvieSpecError>()),
      );
    });
  });

  test('every wave-2 preset carries the timing tail', () {
    final animation = _build({
      'preset': 'bloom',
      'amount': 0.5,
      'duration': '18f',
      'delay': '3f',
      'label': 'glow',
    });
    expect(animation.label, 'glow');
    final tracked = AnchorTable();
    final reactive = _build({
      'preset': 'scaleY',
      'on': 'treble',
      'label': 'bars',
      'delay': '2f',
    }, tracked);
    expect(reactive.label, 'bars');
  });
}
