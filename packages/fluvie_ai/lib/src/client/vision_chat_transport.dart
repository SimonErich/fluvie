import 'dart:async';
import 'dart:convert';

import 'package:fluvie_ai/src/client/ai_client.dart';
import 'package:fluvie_ai/src/client/evidence_image_limits.dart';
import 'package:http/http.dart' as http;

/// Sends original references to chat providers whose text adapter cannot carry
/// images. Explicit captions and their image bytes stay in the same turn.
Future<AiResponse> generateVisionChat(
  AiRequest request, {
  required String model,
  required Uri endpoint,
  required bool ollama,
  http.Client? httpClient,
  String? apiKey,
}) async {
  final images = request.messages.map((turn) => turn.image).whereType<AiImage>();
  checkEvidenceImageLimits(images);
  final body = <String, Object?>{
    'model': model,
    'messages': [for (final turn in request.messages) _message(turn, ollama: ollama)],
    if (ollama) ...{
      'stream': false,
      if (request.jsonSchema != null) 'format': request.jsonSchema,
      'options': {'temperature': request.temperature, 'num_predict': request.maxTokens},
    } else ...{
      'max_tokens': request.maxTokens,
      'temperature': request.temperature,
      if (request.jsonSchema != null) 'response_format': {'type': 'json_object'},
    },
  };
  final client = httpClient ?? http.Client();
  try {
    final response = await client
        .post(
          endpoint,
          headers: {
            'Content-Type': 'application/json',
            if (apiKey != null) 'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(minutes: 2));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiClientException(
        'Vision request failed with HTTP ${response.statusCode}. Check credentials, endpoint, and a vision-capable model.',
      );
    }
    final json = jsonDecode(response.body);
    if (json is! Map<String, Object?>) {
      throw AiClientException('Vision provider returned an unexpected response shape.');
    }
    final choices = json['choices'];
    final first = choices is List<Object?> ? choices.firstOrNull : null;
    final message = ollama
        ? json['message']
        : (first is Map<String, Object?> ? first['message'] : null);
    final text = message is Map<String, Object?> ? message['content'] : null;
    if (text is! String || text.isEmpty) {
      throw AiClientException('Vision provider returned no message content.');
    }
    return AiResponse(text);
  } on AiClientException {
    rethrow;
  } on TimeoutException {
    throw AiClientException('Vision request timed out after two minutes.');
  } on FormatException {
    throw AiClientException('Vision provider returned malformed JSON.');
  } on http.ClientException {
    throw AiClientException('Could not connect to the vision provider. Check its endpoint.');
  } finally {
    if (httpClient == null) client.close();
  }
}

Map<String, Object?> _message(AiMessage turn, {required bool ollama}) {
  final image = turn.image;
  return {
    'role': turn.role.name,
    'content': image == null || ollama
        ? turn.text
        : [
            {'type': 'text', 'text': turn.text},
            {
              'type': 'image_url',
              'image_url': {'url': 'data:${image.mediaType};base64,${base64Encode(image.bytes)}'},
            },
          ],
    if (image != null && ollama) 'images': [base64Encode(image.bytes)],
  };
}
