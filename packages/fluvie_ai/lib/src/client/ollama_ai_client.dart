import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:fluvie_ai/src/client/ai_client.dart';
import 'package:fluvie_ai/src/client/text_generator_adapter.dart';
import 'package:http/http.dart' as http;

/// An [AiClient] backed by a local Ollama server (`/api/chat`).
///
/// Delegates to `ai_abstracted`'s [OllamaTextClient]. Needs no API key — it
/// talks to a local daemon (default `http://localhost:11434`) and forces valid
/// JSON when a schema is set; great for offline development and tests.
final class OllamaAiClient implements AiClient {
  /// Creates a client targeting [model] on the Ollama server at [endpoint]
  /// (default `http://localhost:11434/api/chat`). [httpClient] is injectable.
  OllamaAiClient({
    this.model = 'llama3.1',
    http.Client? httpClient,
    Uri? endpoint,
  }) : _text = OllamaTextClient(
         credentials: const ProviderCredentials(apiKey: ''),
         httpClient: httpClient,
         endpoint: endpoint,
       );

  final OllamaTextClient _text;

  /// The Ollama model name (defaults to `llama3.1`).
  final String model;

  @override
  bool get supportsStructuredOutput => true;

  @override
  Future<AiResponse> generate(AiRequest request) =>
      generateViaTextGenerator(_text, request, model: model);
}
