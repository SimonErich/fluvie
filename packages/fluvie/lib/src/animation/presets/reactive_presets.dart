import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/effects/reactive_effect.dart';
import 'package:fluvie/src/animation/presets/preset_tail.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/core/audio_band.dart';

/// Builds `Animation.scaleY`: a `during`
/// [ReactiveEffect] in [ReactiveMode.scaleY] reading [band] (scoped to [track])
/// scaled by [gain].
///
/// The effect ignores window progress and reads the precomputed band table per
/// frame, so the reactive animation spans the whole window. Kept a one-line
/// delegation so the facade member stays thin.
Animation buildReactiveScaleY(AudioBand band, double gain, Anchor? track, AmbientTail tail) =>
    Animation.custom(
      ReactiveEffect(mode: ReactiveMode.scaleY, band: band, gain: gain, track: track),
      phase: AnimationPhase.during,
      delay: tail.delay,
      at: tail.at,
      stagger: tail.stagger,
      repeat: tail.repeat,
      label: tail.label,
    );

/// Builds the reactive form of `Animation.pulse`: a
/// `during` [ReactiveEffect] in [ReactiveMode.pulse] reading [band] (scoped to
/// [track]) scaled by [gain].
///
/// This is the branch `Animation.pulse(on:)` takes; the sine-form `pulse()`
/// (with no band) keeps its existing keyframe builder untouched.
Animation buildReactivePulse(AudioBand band, double gain, Anchor? track, AmbientTail tail) =>
    Animation.custom(
      ReactiveEffect(mode: ReactiveMode.pulse, band: band, gain: gain, track: track),
      phase: AnimationPhase.during,
      delay: tail.delay,
      at: tail.at,
      stagger: tail.stagger,
      repeat: tail.repeat,
      label: tail.label,
    );
