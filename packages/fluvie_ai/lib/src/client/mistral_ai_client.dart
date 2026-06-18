import 'package:fluvie_ai/src/client/ai_client.dart';
import 'package:fluvie_ai/src/client/json_http.dart';
import 'package:http/http.dart' as http;

/// An [AiClient] backed by the Mistral chat-completions API.
///
/// Uses the OpenAI-style message shape and `response_format: json_object` to
/// force valid JSON, leaving full-schema validation to the repair loop.
class MistralAiClient implements AiClient {
  /// Creates a client authenticating with [apiKey], targeting [model].
  ///
  /// [httpClient] and [endpoint] are injectable for tests.
  MistralAiClient({
    required String apiKey,
    this.model = 'mistral-large-latest',
    http.Client? httpClient,
    Uri? endpoint,
  }) : _apiKey = apiKey, // ignore: prefer_initializing_formals — public arg, private field
       _http = httpClient ?? http.Client(),
       _endpoint = endpoint ?? Uri.parse('https://api.mistral.ai/v1/chat/completions');

  final String _apiKey;
  final http.Client _http;
  final Uri _endpoint;

  /// The Mistral model id (defaults to `mistral-large-latest`).
  final String model;

  @override
  bool get supportsStructuredOutput => true;

  @override
  Future<AiResponse> generate(AiRequest request) async {
    final json = await postJson(
      _http,
      _endpoint,
      {'authorization': 'Bearer $_apiKey'},
      {
        'model': model,
        'temperature': request.temperature,
        'max_tokens': request.maxTokens,
        'response_format': {'type': 'json_object'},
        'messages': [
          for (final message in request.messages)
            {'role': _role(message.role), 'content': message.text},
        ],
      },
      provider: 'Mistral',
    );
    final choices = json['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map<String, Object?>) {
        final message = first['message'];
        if (message is Map<String, Object?> && message['content'] is String) {
          return AiResponse(message['content']! as String);
        }
      }
    }
    throw AiClientException('Mistral returned no message content');
  }
}

String _role(AiRole role) => switch (role) {
  AiRole.system => 'system',
  AiRole.assistant => 'assistant',
  AiRole.user => 'user',
};
