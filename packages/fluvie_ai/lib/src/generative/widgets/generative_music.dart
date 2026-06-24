import 'package:flutter/widgets.dart' show Key;
import 'package:fluvie/fluvie.dart';

/// Provider sugar for an AI-generated music track.
///
/// Builds the provider-agnostic [GenerativeAudio] with a music [GenerativeSource]
/// so the prerender pass produces it once (cached by prompt + seed + params) and
/// it then mixes like a local music bed. Generated music also feeds beat
/// detection, so `Trigger.beat` works against it.
///
/// ```dart
/// GenerativeMusic.suno(prompt: 'lofi hip hop, 90bpm', seconds: 10)
/// ```
abstract final class GenerativeMusic {
  /// A Suno (via sunoapi.org) music track from [prompt], about [seconds] long.
  static GenerativeAudio suno({
    required String prompt,
    double? seconds,
    String? seed,
    bool instrumental = false,
    double volume = 1,
    Time? fadeIn,
    Time? fadeOut,
    bool loop = false,
    Key? key,
  }) => GenerativeAudio(
    source: GenerativeSource.music(
      providerId: 'suno',
      prompt: prompt,
      seed: seed,
      params: {'seconds': ?seconds, 'instrumental': instrumental},
    ),
    volume: volume,
    fadeIn: fadeIn,
    fadeOut: fadeOut,
    loop: loop,
    key: key,
  );
}
