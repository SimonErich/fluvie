import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:test/test.dart';

void main() {
  group('credentialsFromEnv', () {
    test('reads each provider from its env key', () {
      String? keyFor(ProviderId provider, Map<String, String> env) =>
          credentialsFromEnv(provider, env)?.apiKey;

      expect(keyFor(ProviderId.gemini, {'GEMINI_API_KEY': 'g'}), 'g');
      expect(keyFor(ProviderId.veo, {'GEMINI_API_KEY': 'g'}), 'g');
      expect(keyFor(ProviderId.openai, {'OPENAI_API_KEY': 'o'}), 'o');
      expect(keyFor(ProviderId.flux, {'BFL_API_KEY': 'b'}), 'b');
      expect(keyFor(ProviderId.elevenLabs, {'ELEVENLABS_API_KEY': 'e'}), 'e');
      expect(keyFor(ProviderId.suno, {'SUNO_API_KEY': 's'}), 's');
      expect(keyFor(ProviderId.claude, {'ANTHROPIC_API_KEY': 'a'}), 'a');
      expect(keyFor(ProviderId.mistral, {'MISTRAL_API_KEY': 'm'}), 'm');
    });

    test('veo prefers the FLUVIE_VEO_API_KEY override', () {
      final credentials = credentialsFromEnv(ProviderId.veo, {
        'GEMINI_API_KEY': 'g',
        'FLUVIE_VEO_API_KEY': 'v',
      });
      expect(credentials?.apiKey, 'v');
    });

    test('returns null when the key is absent', () {
      expect(credentialsFromEnv(ProviderId.gemini, const {}), isNull);
      expect(credentialsFromEnv(ProviderId.openai, const {'GEMINI_API_KEY': 'g'}), isNull);
    });

    test('ollama is keyless and always resolves to empty credentials', () {
      final credentials = credentialsFromEnv(ProviderId.ollama, const {});
      expect(credentials, isNotNull);
      expect(credentials!.apiKey, isEmpty);
    });
  });

  group('allCredentialsFromEnv', () {
    test('maps only the providers present in the env (plus ollama)', () {
      final all = allCredentialsFromEnv(const {
        'OPENAI_API_KEY': 'o',
        'SUNO_API_KEY': 's',
      });
      expect(all.keys, containsAll([ProviderId.openai, ProviderId.suno, ProviderId.ollama]));
      expect(all.containsKey(ProviderId.gemini), isFalse);
      expect(all[ProviderId.openai]!.apiKey, 'o');
    });

    test('a single GEMINI key resolves both gemini and veo', () {
      final all = allCredentialsFromEnv(const {'GEMINI_API_KEY': 'g'});
      expect(all[ProviderId.gemini]!.apiKey, 'g');
      expect(all[ProviderId.veo]!.apiKey, 'g');
    });
  });
}
