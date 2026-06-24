import 'package:ai_abstracted/src/config/provider_credentials.dart';
import 'package:ai_abstracted/src/contracts/image_generator.dart';
import 'package:ai_abstracted/src/contracts/music_generator.dart';
import 'package:ai_abstracted/src/contracts/sound_effect_generator.dart';
import 'package:ai_abstracted/src/contracts/speech_generator.dart';
import 'package:ai_abstracted/src/contracts/text_generator.dart';
import 'package:ai_abstracted/src/contracts/video_generator.dart';
import 'package:ai_abstracted/src/core/ai_exception.dart';
import 'package:ai_abstracted/src/providers/anthropic/claude_text_client.dart';
import 'package:ai_abstracted/src/providers/bfl/flux_image_client.dart';
import 'package:ai_abstracted/src/providers/elevenlabs/elevenlabs_sound_effect_client.dart';
import 'package:ai_abstracted/src/providers/elevenlabs/elevenlabs_speech_client.dart';
import 'package:ai_abstracted/src/providers/google/gemini_image_client.dart';
import 'package:ai_abstracted/src/providers/google/gemini_text_client.dart';
import 'package:ai_abstracted/src/providers/google/veo_video_client.dart';
import 'package:ai_abstracted/src/providers/mistral/mistral_text_client.dart';
import 'package:ai_abstracted/src/providers/ollama/ollama_text_client.dart';
import 'package:ai_abstracted/src/providers/openai/openai_image_client.dart';
import 'package:ai_abstracted/src/providers/suno/suno_music_client.dart';
import 'package:ai_abstracted/src/registry/provider_id.dart';
import 'package:http/http.dart' as http;

/// Resolves a [ProviderId] and [ProviderCredentials] to a concrete client.
///
/// Each method returns the provider's implementation of one capability, or
/// throws an [AiInvalidRequestException] when that provider does not offer it.
final class ProviderRegistry {
  /// Creates a [ProviderRegistry].
  const ProviderRegistry();

  /// The [ImageGenerator] for [id], or throws when [id] cannot make images.
  ImageGenerator imageGenerator(
    ProviderId id,
    ProviderCredentials credentials, {
    http.Client? httpClient,
  }) {
    switch (id) {
      case ProviderId.gemini:
        return GeminiImageClient(credentials: credentials, httpClient: httpClient);
      case ProviderId.openai:
        return OpenAiImageClient(credentials: credentials, httpClient: httpClient);
      case ProviderId.flux:
        return FluxImageClient(credentials: credentials, httpClient: httpClient);
      case ProviderId.veo:
      case ProviderId.elevenLabs:
      case ProviderId.suno:
      case ProviderId.claude:
      case ProviderId.mistral:
      case ProviderId.ollama:
        throw _unsupported(id, 'image');
    }
  }

  /// The [VideoGenerator] for [id], or throws when [id] cannot make video.
  VideoGenerator videoGenerator(
    ProviderId id,
    ProviderCredentials credentials, {
    http.Client? httpClient,
  }) {
    if (id == ProviderId.veo) {
      return VeoVideoClient(credentials: credentials, httpClient: httpClient);
    }
    throw _unsupported(id, 'video');
  }

  /// The [SpeechGenerator] for [id], or throws when [id] cannot make speech.
  SpeechGenerator speechGenerator(
    ProviderId id,
    ProviderCredentials credentials, {
    http.Client? httpClient,
  }) {
    if (id == ProviderId.elevenLabs) {
      return ElevenLabsSpeechClient(credentials: credentials, httpClient: httpClient);
    }
    throw _unsupported(id, 'speech');
  }

  /// The [SoundEffectGenerator] for [id], or throws when [id] cannot make one.
  SoundEffectGenerator soundEffectGenerator(
    ProviderId id,
    ProviderCredentials credentials, {
    http.Client? httpClient,
  }) {
    if (id == ProviderId.elevenLabs) {
      return ElevenLabsSoundEffectClient(credentials: credentials, httpClient: httpClient);
    }
    throw _unsupported(id, 'sound effect');
  }

  /// The [MusicGenerator] for [id], or throws when [id] cannot make music.
  MusicGenerator musicGenerator(
    ProviderId id,
    ProviderCredentials credentials, {
    http.Client? httpClient,
  }) {
    if (id == ProviderId.suno) {
      return SunoMusicClient(credentials: credentials, httpClient: httpClient);
    }
    throw _unsupported(id, 'music');
  }

  /// The [TextGenerator] for [id], or throws when [id] has no text client.
  TextGenerator textGenerator(
    ProviderId id,
    ProviderCredentials credentials, {
    http.Client? httpClient,
  }) {
    switch (id) {
      case ProviderId.gemini:
        return GeminiTextClient(credentials: credentials, httpClient: httpClient);
      case ProviderId.claude:
        return ClaudeTextClient(credentials: credentials, httpClient: httpClient);
      case ProviderId.mistral:
        return MistralTextClient(credentials: credentials, httpClient: httpClient);
      case ProviderId.ollama:
        return OllamaTextClient(credentials: credentials, httpClient: httpClient);
      case ProviderId.veo:
      case ProviderId.openai:
      case ProviderId.flux:
      case ProviderId.elevenLabs:
      case ProviderId.suno:
        throw _unsupported(id, 'text');
    }
  }

  AiInvalidRequestException _unsupported(ProviderId id, String capability) =>
      AiInvalidRequestException(
        'Provider "${id.id}" does not support $capability generation',
        provider: id.id,
      );
}
