import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:fluvie/fluvie.dart';
import 'package:http/http.dart' as http;

/// Resolves a [GenerativeSource.providerId] string to an ai_abstracted
/// [ProviderId], throwing a [FluvieGenerativeException] for an unknown name.
ProviderId providerIdFor(String providerId) => ProviderId.values.firstWhere(
  (provider) => provider.id == providerId,
  orElse: () => throw FluvieGenerativeException(
    'Unknown generative provider "$providerId". Known: '
    '${ProviderId.values.map((p) => p.id).join(', ')}.',
  ),
);

/// Calls the ai_abstracted generator that matches [source]'s kind through
/// [registry], authenticated with [credentials].
///
/// The provider-specific options live in [GenerativeSource.params]; this maps
/// them onto the typed request for each capability. Reports provider progress
/// through [onProgress].
Future<GenerationResult> generateFor(
  GenerativeSource source, {
  required ProviderRegistry registry,
  required ProviderCredentials credentials,
  http.Client? httpClient,
  void Function(GenerationProgress progress)? onProgress,
}) {
  final id = providerIdFor(source.providerId);
  switch (source.kind) {
    case GenerativeKind.image:
      return registry
          .imageGenerator(id, credentials, httpClient: httpClient)
          .generateImage(_imageRequest(source), onProgress: onProgress);
    case GenerativeKind.video:
      return registry
          .videoGenerator(id, credentials, httpClient: httpClient)
          .generateVideo(_videoRequest(source), onProgress: onProgress);
    case GenerativeKind.music:
      return registry
          .musicGenerator(id, credentials, httpClient: httpClient)
          .generateMusic(_musicRequest(source), onProgress: onProgress);
    case GenerativeKind.speech:
      return registry
          .speechGenerator(id, credentials, httpClient: httpClient)
          .generateSpeech(_speechRequest(source), onProgress: onProgress);
    case GenerativeKind.soundEffect:
      return registry
          .soundEffectGenerator(id, credentials, httpClient: httpClient)
          .generateSoundEffect(_soundEffectRequest(source), onProgress: onProgress);
  }
}

ImageRequest _imageRequest(GenerativeSource s) => ImageRequest(
  prompt: s.prompt,
  seed: s.seed,
  model: s.model,
  width: _int(s.params['width']),
  height: _int(s.params['height']),
  aspectRatio: s.params['aspectRatio'] as String?,
);

VideoRequest _videoRequest(GenerativeSource s) => VideoRequest(
  prompt: s.prompt,
  seed: s.seed,
  model: s.model,
  seconds: _double(s.params['seconds']),
  withAudio: s.params['withAudio'] as bool? ?? true,
  fps: _int(s.params['fps']),
  aspectRatio: s.params['aspectRatio'] as String?,
);

MusicRequest _musicRequest(GenerativeSource s) => MusicRequest(
  prompt: s.prompt,
  seed: s.seed,
  model: s.model,
  seconds: _double(s.params['seconds']),
  instrumental: s.params['instrumental'] as bool? ?? false,
);

SpeechRequest _speechRequest(GenerativeSource s) => SpeechRequest(
  prompt: s.prompt,
  seed: s.seed,
  model: s.model,
  voice: s.params['voice'] as String?,
);

SoundEffectRequest _soundEffectRequest(GenerativeSource s) => SoundEffectRequest(
  prompt: s.prompt,
  seed: s.seed,
  model: s.model,
  seconds: _double(s.params['seconds']),
);

int? _int(Object? value) => value is int ? value : (value is num ? value.toInt() : null);
double? _double(Object? value) =>
    value is double ? value : (value is num ? value.toDouble() : null);
