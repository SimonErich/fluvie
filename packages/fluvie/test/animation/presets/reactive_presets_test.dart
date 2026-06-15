import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/effects/reactive_effect.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/core/audio_band.dart';

void main() {
  group('Animation.scaleY', () {
    test('expands to a during ReactiveEffect in scaleY mode', () {
      final animation = Animation.scaleY(on: AudioBand.bass, gain: 1.5);
      expect(animation.phase, AnimationPhase.during);
      final effect = animation.effect;
      expect(effect, isA<ReactiveEffect>());
      expect((effect as ReactiveEffect).mode, ReactiveMode.scaleY);
      expect(effect.band, AudioBand.bass);
      expect(effect.gain, 1.5);
    });

    test('defaults gain to 1.0', () {
      final effect = Animation.scaleY(on: AudioBand.treble).effect as ReactiveEffect;
      expect(effect.gain, 1.0);
      expect(effect.band, AudioBand.treble);
    });

    test('carries the track anchor', () {
      final beat = Anchor('beat');
      final effect = Animation.scaleY(on: AudioBand.bass, track: beat).effect as ReactiveEffect;
      expect(effect.track, same(beat));
    });

    test('two identical expansions have equal effects', () {
      final a = Animation.scaleY(on: AudioBand.mid, gain: 2).effect as ReactiveEffect;
      final b = Animation.scaleY(on: AudioBand.mid, gain: 2).effect as ReactiveEffect;
      expect(a.mode, b.mode);
      expect(a.band, b.band);
      expect(a.gain, b.gain);
    });
  });

  group('Animation.pulse with on:', () {
    test('is a during ReactiveEffect in pulse mode', () {
      final animation = Animation.pulse(on: AudioBand.bass, gain: 1.2);
      expect(animation.phase, AnimationPhase.during);
      final effect = animation.effect;
      expect(effect, isA<ReactiveEffect>());
      expect((effect as ReactiveEffect).mode, ReactiveMode.pulse);
      expect(effect.band, AudioBand.bass);
      expect(effect.gain, 1.2);
    });

    test('carries the track anchor', () {
      final beat = Anchor('beat');
      final effect = Animation.pulse(on: AudioBand.bass, track: beat).effect as ReactiveEffect;
      expect(effect.track, same(beat));
    });
  });

  group('Animation.pulse without on: stays the sine form (regression pin)', () {
    test('is NOT a ReactiveEffect when on is null', () {
      final animation = Animation.pulse();
      expect(animation.effect, isNot(isA<ReactiveEffect>()));
      expect(animation.phase, AnimationPhase.during);
    });

    test('still accepts the sine-form min/max/period parameters', () {
      // The original surface compiles and produces a non-reactive during effect.
      final animation = Animation.pulse(min: 0.9, max: 1.1);
      expect(animation.effect, isNot(isA<ReactiveEffect>()));
    });
  });
}
