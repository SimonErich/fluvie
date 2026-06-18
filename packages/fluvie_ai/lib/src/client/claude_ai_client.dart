import 'dart:convert';

import 'package:fluvie_ai/src/client/ai_client.dart';
import 'package:fluvie_ai/src/client/json_http.dart';
import 'package:http/http.dart' as http;

/// An [AiClient] backed by the Anthropic Messages API (Claude).
///
/// Sends the system prompt as the top-level `system` field and the rest of the
/// conversation as `user`/`assistant` turns. The schema is delivered in the
/// prompt (not as native structured output), so the author service's repair
/// loop handles validation — robust across every model.
class ClaudeAiClient implements AiClient {
  /// Creates a client authenticating with [apiKey], targeting [model].
  ///
  /// [httpClient] and [endpoint] are injectable for tests.
  ClaudeAiClient({
    required String apiKey,
    this.model = 'claude-opus-4-8',
    http.Client? httpClient,
    Uri? endpoint,
  }) : _apiKey = apiKey, // ignore: prefer_initializing_formals — public arg, private field
       _http = httpClient ?? http.Client(),
       _endpoint = endpoint ?? Uri.parse('https://api.anthropic.com/v1/messages');

  final String _apiKey;
  final http.Client _http;
  final Uri _endpoint;

  /// The Claude model id (defaults to `claude-opus-4-8`).
  final String model;

  @override
  bool get supportsStructuredOutput => false;

  @override
  Future<AiResponse> generate(AiRequest request) async {
    final system = request.messages
        .where((message) => message.role == AiRole.system)
        .map((message) => message.text)
        .join('\n\n');
    final turns = [
      for (final message in request.messages)
        if (message.role != AiRole.system)
          {
            'role': message.role == AiRole.assistant ? 'assistant' : 'user',
            'content': _content(message),
          },
    ];
    final json = await postJson(
      _http,
      _endpoint,
      {'x-api-key': _apiKey, 'anthropic-version': '2023-06-01'},
      {
        'model': model,
        'max_tokens': request.maxTokens,
        if (system.isNotEmpty) 'system': system,
        'messages': turns,
      },
      provider: 'Claude',
    );
    if (json['stop_reason'] == 'refusal') {
      throw AiClientException('Claude declined the request (stop_reason: refusal)');
    }
    final content = json['content'];
    if (content is List) {
      for (final block in content) {
        if (block is Map<String, Object?> && block['type'] == 'text' && block['text'] is String) {
          return AiResponse(block['text']! as String);
        }
      }
    }
    throw AiClientException('Claude returned no text content');
  }

  /// A message's content: a plain string, or — when an image is attached — a
  /// `[text, image]` content-block list (Anthropic base64 image source).
  Object _content(AiMessage message) {
    final image = message.image;
    if (image == null) return message.text;
    return [
      {'type': 'text', 'text': message.text},
      {
        'type': 'image',
        'source': {
          'type': 'base64',
          'media_type': image.mediaType,
          'data': base64Encode(image.bytes),
        },
      },
    ];
  }
}
