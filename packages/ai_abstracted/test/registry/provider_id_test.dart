import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:test/test.dart';

void main() {
  group('ProviderId', () {
    test('has the nine locked providers', () {
      expect(ProviderId.values, [
        ProviderId.gemini,
        ProviderId.veo,
        ProviderId.openai,
        ProviderId.flux,
        ProviderId.elevenLabs,
        ProviderId.suno,
        ProviderId.claude,
        ProviderId.mistral,
        ProviderId.ollama,
      ]);
    });

    test('id is a stable lower-case wire name', () {
      expect(ProviderId.gemini.id, 'gemini');
      expect(ProviderId.veo.id, 'veo');
      expect(ProviderId.openai.id, 'openai');
      expect(ProviderId.flux.id, 'flux');
      expect(ProviderId.elevenLabs.id, 'elevenlabs');
      expect(ProviderId.suno.id, 'suno');
      expect(ProviderId.claude.id, 'claude');
      expect(ProviderId.mistral.id, 'mistral');
      expect(ProviderId.ollama.id, 'ollama');
    });
  });
}
