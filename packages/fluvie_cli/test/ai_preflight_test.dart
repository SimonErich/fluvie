import 'package:fluvie_cli/src/ai_preflight.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:test/test.dart';

void main() {
  test('rejects missing keys before harness startup without printing values', () {
    expect(
      () => validateAiEnvironment(const {}),
      throwsA(
        isA<CliFailure>()
            .having((e) => e.message, 'message', contains('ANTHROPIC_API_KEY'))
            .having((e) => e.code, 'code', 'provider_not_configured'),
      ),
    );
    expect(
      () => validateAiEnvironment(const {'FLUVIE_AI_PROVIDER': 'gemini', 'GEMINI_API_KEY': ' '}),
      throwsA(isA<CliFailure>()),
    );
    expect(
      validateAiEnvironment(const {'ANTHROPIC_API_KEY': 'secret-not-disclosed'}),
      'claude',
    );
  });

  test('Ollama works without a key; explicit provider wins; validates custom endpoint', () {
    expect(validateAiEnvironment(const {}, provider: 'ollama'), 'ollama');
    expect(
      validateAiEnvironment(const {'FLUVIE_AI_PROVIDER': 'unknown'}, provider: 'ollama'),
      'ollama',
    );
    for (final endpoint in ['file:///tmp/socket', 'https://', 'relative']) {
      expect(
        () => validateAiEnvironment({'FLUVIE_AI_ENDPOINT': endpoint}, provider: 'ollama'),
        throwsA(isA<CliFailure>().having((e) => e.code, 'code', 'invalid_provider_endpoint')),
      );
    }
    expect(
      validateAiEnvironment(const {
        'FLUVIE_AI_ENDPOINT': 'http://localhost:11434/api/chat',
      }, provider: 'ollama'),
      'ollama',
    );
    expect(
      () => validateAiEnvironment(const {}, provider: 'unknown'),
      throwsA(isA<CliFailure>().having((e) => e.code, 'code', 'invalid_provider')),
    );
  });
}
