import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_example/render/ai_authoring.dart';

void main() {
  group('aiEnvForProvider', () {
    test('overrides FLUVIE_AI_PROVIDER when a provider is given', () {
      final env = aiEnvForProvider(const {'GEMINI_API_KEY': 'k'}, 'gemini');

      expect(env['FLUVIE_AI_PROVIDER'], 'gemini');
      expect(env['GEMINI_API_KEY'], 'k', reason: 'the base env must be preserved');
    });

    test('returns the base env unchanged for a null or empty provider', () {
      const base = {'FLUVIE_AI_PROVIDER': 'claude', 'ANTHROPIC_API_KEY': 'k'};

      expect(aiEnvForProvider(base, null), base);
      expect(aiEnvForProvider(base, ''), base);
    });

    test('a given provider wins over one already present in the base env', () {
      final env = aiEnvForProvider(const {'FLUVIE_AI_PROVIDER': 'claude'}, 'gemini');

      expect(env['FLUVIE_AI_PROVIDER'], 'gemini');
    });
  });
}
