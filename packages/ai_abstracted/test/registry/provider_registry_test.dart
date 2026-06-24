import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:test/test.dart';

const _creds = ProviderCredentials(apiKey: 'k');

void main() {
  const registry = ProviderRegistry();

  group('imageGenerator', () {
    test('resolves the image-capable providers', () {
      expect(registry.imageGenerator(ProviderId.gemini, _creds), isA<GeminiImageClient>());
      expect(registry.imageGenerator(ProviderId.openai, _creds), isA<OpenAiImageClient>());
      expect(registry.imageGenerator(ProviderId.flux, _creds), isA<FluxImageClient>());
    });

    test('throws for any provider without image support', () {
      for (final id in [
        ProviderId.veo,
        ProviderId.elevenLabs,
        ProviderId.suno,
        ProviderId.claude,
        ProviderId.mistral,
        ProviderId.ollama,
      ]) {
        expect(
          () => registry.imageGenerator(id, _creds),
          throwsA(isA<AiInvalidRequestException>()),
          reason: '$id should not support image',
        );
      }
    });
  });

  test('videoGenerator resolves Veo and rejects others', () {
    expect(registry.videoGenerator(ProviderId.veo, _creds), isA<VeoVideoClient>());
    expect(
      () => registry.videoGenerator(ProviderId.openai, _creds),
      throwsA(isA<AiInvalidRequestException>()),
    );
  });

  test('speechGenerator resolves ElevenLabs and rejects others', () {
    expect(registry.speechGenerator(ProviderId.elevenLabs, _creds), isA<ElevenLabsSpeechClient>());
    expect(
      () => registry.speechGenerator(ProviderId.suno, _creds),
      throwsA(isA<AiInvalidRequestException>()),
    );
  });

  test('soundEffectGenerator resolves ElevenLabs and rejects others', () {
    expect(
      registry.soundEffectGenerator(ProviderId.elevenLabs, _creds),
      isA<ElevenLabsSoundEffectClient>(),
    );
    expect(
      () => registry.soundEffectGenerator(ProviderId.gemini, _creds),
      throwsA(isA<AiInvalidRequestException>()),
    );
  });

  test('musicGenerator resolves Suno and rejects others', () {
    expect(registry.musicGenerator(ProviderId.suno, _creds), isA<SunoMusicClient>());
    expect(
      () => registry.musicGenerator(ProviderId.veo, _creds),
      throwsA(isA<AiInvalidRequestException>()),
    );
  });

  group('textGenerator', () {
    test('resolves every text-capable provider', () {
      expect(registry.textGenerator(ProviderId.gemini, _creds), isA<GeminiTextClient>());
      expect(registry.textGenerator(ProviderId.claude, _creds), isA<ClaudeTextClient>());
      expect(registry.textGenerator(ProviderId.mistral, _creds), isA<MistralTextClient>());
      expect(registry.textGenerator(ProviderId.ollama, _creds), isA<OllamaTextClient>());
    });

    test('throws for providers without an implemented text client', () {
      for (final id in [
        ProviderId.veo,
        ProviderId.openai,
        ProviderId.flux,
        ProviderId.elevenLabs,
        ProviderId.suno,
      ]) {
        expect(
          () => registry.textGenerator(id, _creds),
          throwsA(isA<AiInvalidRequestException>()),
          reason: '$id should not support text',
        );
      }
    });
  });
}
