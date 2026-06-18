import 'package:fluvie_ai/src/client/ai_client.dart';
import 'package:fluvie_ai/src/client/claude_ai_client.dart';
import 'package:fluvie_ai/src/client/gemini_ai_client.dart';
import 'package:fluvie_ai/src/client/mistral_ai_client.dart';
import 'package:fluvie_ai/src/client/ollama_ai_client.dart';

/// Builds an [AiClient] from environment variables.
///
/// `FLUVIE_AI_PROVIDER` selects the backend (`claude` (default), `gemini`,
/// `mistral`, or `ollama`); `FLUVIE_AI_MODEL` overrides the model. API keys come
/// from `ANTHROPIC_API_KEY` / `GEMINI_API_KEY` / `MISTRAL_API_KEY` (Ollama needs
/// none). Pass the environment in (e.g. `Platform.environment`) so this stays
/// pure and testable.
///
/// Throws an [AiClientException] for an unknown provider or a missing key.
AiClient aiClientFromEnv(Map<String, String> env) {
  final provider = env['FLUVIE_AI_PROVIDER'] ?? 'claude';
  final model = env['FLUVIE_AI_MODEL'];
  switch (provider) {
    case 'claude':
      return ClaudeAiClient(
        apiKey: _require(env, 'ANTHROPIC_API_KEY'),
        model: model ?? 'claude-opus-4-8',
      );
    case 'gemini':
      return GeminiAiClient(
        apiKey: _require(env, 'GEMINI_API_KEY'),
        model: model ?? 'gemini-2.5-pro',
      );
    case 'mistral':
      return MistralAiClient(
        apiKey: _require(env, 'MISTRAL_API_KEY'),
        model: model ?? 'mistral-large-latest',
      );
    case 'ollama':
      return OllamaAiClient(model: model ?? 'llama3.1');
  }
  throw AiClientException(
    'Unknown FLUVIE_AI_PROVIDER "$provider"; expected claude, gemini, mistral, or ollama',
  );
}

String _require(Map<String, String> env, String key) {
  final value = env[key];
  if (value == null || value.isEmpty) {
    throw AiClientException('Missing required environment variable $key');
  }
  return value;
}
