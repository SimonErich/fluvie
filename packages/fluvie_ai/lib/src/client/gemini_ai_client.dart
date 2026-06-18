import 'dart:convert';

import 'package:fluvie_ai/src/client/ai_client.dart';
import 'package:fluvie_ai/src/client/json_http.dart';
import 'package:http/http.dart' as http;

/// An [AiClient] backed by the Google Gemini `generateContent` API.
///
/// Maps the system prompt to `systemInstruction`, assistant turns to the `model`
/// role, and enables JSON output via `responseMimeType` — robust without
/// committing to a strict response schema.
class GeminiAiClient implements AiClient {
  /// Creates a client authenticating with [apiKey], targeting [model].
  ///
  /// [httpClient] and [endpoint] (the full `generateContent` URL) are injectable
  /// for tests; [endpoint] otherwise derives from [model].
  GeminiAiClient({
    required String apiKey,
    this.model = 'gemini-2.5-pro',
    http.Client? httpClient,
    Uri? endpoint,
  }) : _apiKey = apiKey, // ignore: prefer_initializing_formals — public arg, private field
       _http = httpClient ?? http.Client(),
       _endpoint = endpoint; // ignore: prefer_initializing_formals — public arg, private field

  final String _apiKey;
  final http.Client _http;
  final Uri? _endpoint;

  /// The Gemini model id (defaults to `gemini-2.5-pro`).
  final String model;

  @override
  bool get supportsStructuredOutput => true;

  @override
  Future<AiResponse> generate(AiRequest request) async {
    final system = request.messages
        .where((message) => message.role == AiRole.system)
        .map((message) => message.text)
        .join('\n\n');
    final contents = [
      for (final message in request.messages)
        if (message.role != AiRole.system)
          {
            'role': message.role == AiRole.assistant ? 'model' : 'user',
            'parts': _parts(message),
          },
    ];
    final uri =
        _endpoint ??
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent');
    final json = await postJson(
      _http,
      uri,
      {'x-goog-api-key': _apiKey},
      {
        if (system.isNotEmpty)
          'systemInstruction': {
            'parts': [
              {'text': system},
            ],
          },
        'contents': contents,
        'generationConfig': {
          'responseMimeType': 'application/json',
          'temperature': request.temperature,
        },
      },
      provider: 'Gemini',
    );
    final candidates = json['candidates'];
    if (candidates is List && candidates.isNotEmpty) {
      final first = candidates.first;
      if (first is Map<String, Object?>) {
        final content = first['content'];
        if (content is Map<String, Object?>) {
          final parts = content['parts'];
          if (parts is List) {
            final buffer = StringBuffer();
            for (final part in parts) {
              if (part is Map<String, Object?> && part['text'] is String) {
                buffer.write(part['text']);
              }
            }
            if (buffer.isNotEmpty) return AiResponse(buffer.toString());
          }
        }
      }
    }
    throw AiClientException('Gemini returned no text content');
  }

  /// A message's parts: the text, plus an `inlineData` part when an image is
  /// attached (base64-encoded with its media type).
  List<Object> _parts(AiMessage message) {
    final parts = <Object>[
      {'text': message.text},
    ];
    final image = message.image;
    if (image != null) {
      parts.add({
        'inlineData': {'mimeType': image.mediaType, 'data': base64Encode(image.bytes)},
      });
    }
    return parts;
  }
}
