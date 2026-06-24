import 'package:flutter/widgets.dart' show Key;
import 'package:fluvie/fluvie.dart';

/// Provider sugar for an AI-generated sound effect.
///
/// Builds the provider-agnostic [GenerativeAudio] with a sound-effect
/// [GenerativeSource] so the prerender pass produces it once (cached by prompt +
/// seed + params) and it then mixes like a local effect.
///
/// ```dart
/// GenerativeSoundFx.eleven(prompt: 'a short whoosh', seconds: 1.5)
/// ```
abstract final class GenerativeSoundFx {
  /// An ElevenLabs sound effect from [prompt], about [seconds] long.
  static GenerativeAudio eleven({
    required String prompt,
    double? seconds,
    String? seed,
    double volume = 1,
    Key? key,
  }) => GenerativeAudio(
    source: GenerativeSource.soundEffect(
      providerId: 'elevenlabs',
      prompt: prompt,
      seed: seed,
      params: {'seconds': ?seconds},
    ),
    volume: volume,
    key: key,
  );
}
