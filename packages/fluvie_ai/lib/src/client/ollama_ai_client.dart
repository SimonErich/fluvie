import 'package:fluvie_ai/src/client/ai_client.dart';
import 'package:fluvie_ai/src/client/json_http.dart';
import 'package:http/http.dart' as http;

/// An [AiClient] backed by a local Ollama server (`/api/chat`).
///
/// Needs no API key — it talks to a local daemon (default
/// `http://localhost:11434`). Uses `format: json` to force valid JSON output;
/// great for offline development and tests.
class OllamaAiClient implements AiClient {
  /// Creates a client targeting [model] on the Ollama server at [endpoint]
  /// (default `http://localhost:11434/api/chat`). [httpClient] is injectable.
  OllamaAiClient({
    this.model = 'llama3.1',
    http.Client? httpClient,
    Uri? endpoint,
  }) : _http = httpClient ?? http.Client(),
       _endpoint = endpoint ?? Uri.parse('http://localhost:11434/api/chat');

  final http.Client _http;
  final Uri _endpoint;

  /// The Ollama model name (defaults to `llama3.1`).
  final String model;

  @override
  bool get supportsStructuredOutput => true;

  @override
  Future<AiResponse> generate(AiRequest request) async {
    final json = await postJson(
      _http,
      _endpoint,
      const {},
      {
        'model': model,
        'stream': false,
        'format': 'json',
        'options': {'temperature': request.temperature},
        'messages': [
          for (final message in request.messages)
            {'role': _role(message.role), 'content': message.text},
        ],
      },
      provider: 'Ollama',
    );
    final message = json['message'];
    if (message is Map<String, Object?> && message['content'] is String) {
      return AiResponse(message['content']! as String);
    }
    throw AiClientException('Ollama returned no message content');
  }
}

String _role(AiRole role) => switch (role) {
  AiRole.system => 'system',
  AiRole.assistant => 'assistant',
  AiRole.user => 'user',
};
