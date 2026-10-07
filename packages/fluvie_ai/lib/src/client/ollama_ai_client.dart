import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:fluvie_ai/src/client/ai_client.dart';
import 'package:fluvie_ai/src/client/text_generator_adapter.dart';
import 'package:fluvie_ai/src/client/vision_chat_transport.dart';
import 'package:http/http.dart' as http;

/// An [AiClient] backed by a local Ollama server (`/api/chat`).
///
/// Uses `ai_abstracted`'s [OllamaTextClient] for text and preserves original
/// image references through native chat messages for vision requests. Needs no
/// API key. Select a vision-capable [model] when supplying images.
final class OllamaAiClient implements AiClient {
  /// Creates a client targeting [model] on the Ollama server at [endpoint]
  /// (default `http://localhost:11434/api/chat`). [httpClient] is injectable.
  OllamaAiClient({
    this.model = 'llama3.1',
    http.Client? httpClient,
    Uri? endpoint,
  }) : _httpClient = httpClient,
       _endpoint = endpoint ?? Uri.parse('http://localhost:11434/api/chat'),
       _text = OllamaTextClient(
         credentials: const ProviderCredentials(apiKey: ''),
         httpClient: httpClient,
         endpoint: endpoint,
       );

  final OllamaTextClient _text;
  final http.Client? _httpClient;
  final Uri _endpoint;

  /// The Ollama model name (defaults to `llama3.1`).
  final String model;

  @override
  bool get supportsStructuredOutput => true;

  @override
  Future<AiResponse> generate(AiRequest request) =>
      request.messages.any((turn) => turn.image != null)
      ? generateVisionChat(
          request,
          model: model,
          endpoint: _endpoint,
          ollama: true,
          httpClient: _httpClient,
        )
      : generateViaTextGenerator(_text, request, model: model);
}
