import 'package:flutter/widgets.dart' show BoxFit, Key;
import 'package:fluvie/fluvie.dart';

/// Provider sugar for an AI-generated still image.
///
/// Each constructor builds the provider-agnostic [GenerativeMedia] with an image
/// [GenerativeSource], so the prerender pass produces it once (cached by prompt +
/// seed + params) and it then paints like a local image. Install the generative
/// resolver (`fluvieGenerativeResolver`) and set the provider's API key.
///
/// ```dart
/// GenerativeImage.flux(prompt: 'a neon skyline at dusk')
/// ```
abstract final class GenerativeImage {
  /// A Flux (Black Forest Labs) image from [prompt].
  static GenerativeMedia flux({
    required String prompt,
    String? seed,
    int? width,
    int? height,
    BoxFit? fit,
    Key? key,
  }) =>
      _image('flux', prompt: prompt, seed: seed, width: width, height: height, fit: fit, key: key);

  /// A Google Gemini ("Nano Banana") image from [prompt].
  static GenerativeMedia gemini({
    required String prompt,
    String? seed,
    int? width,
    int? height,
    BoxFit? fit,
    Key? key,
  }) => _image(
    'gemini',
    prompt: prompt,
    seed: seed,
    width: width,
    height: height,
    fit: fit,
    key: key,
  );

  /// An OpenAI (gpt-image-1) image from [prompt].
  static GenerativeMedia openai({
    required String prompt,
    String? seed,
    int? width,
    int? height,
    BoxFit? fit,
    Key? key,
  }) => _image(
    'openai',
    prompt: prompt,
    seed: seed,
    width: width,
    height: height,
    fit: fit,
    key: key,
  );

  static GenerativeMedia _image(
    String providerId, {
    required String prompt,
    required String? seed,
    required int? width,
    required int? height,
    required BoxFit? fit,
    required Key? key,
  }) => GenerativeMedia(
    source: GenerativeSource.image(
      providerId: providerId,
      prompt: prompt,
      seed: seed,
      params: {'width': ?width, 'height': ?height},
    ),
    fit: fit,
    key: key,
  );
}
