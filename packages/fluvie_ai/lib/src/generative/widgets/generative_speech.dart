import 'package:flutter/widgets.dart' show Key;
import 'package:fluvie/fluvie.dart';

/// Provider sugar for AI-generated speech (text to speech).
///
/// Builds the provider-agnostic [GenerativeAudio] with a speech
/// [GenerativeSource] whose prompt is the text to speak, so the prerender pass
/// produces it once (cached by text + voice + seed) and it then mixes like a
/// local narration track.
///
/// ```dart
/// GenerativeSpeech.eleven(text: 'Welcome to Fluvie', voice: 'rachel')
/// ```
abstract final class GenerativeSpeech {
  /// An ElevenLabs narration of [text] in [voice].
  static GenerativeAudio eleven({
    required String text,
    String? voice,
    String? seed,
    double volume = 1,
    Time? fadeIn,
    Time? fadeOut,
    Key? key,
  }) => GenerativeAudio(
    source: GenerativeSource.speech(
      providerId: 'elevenlabs',
      prompt: text,
      seed: seed,
      params: {'voice': ?voice},
    ),
    volume: volume,
    fadeIn: fadeIn,
    fadeOut: fadeOut,
    key: key,
  );
}
