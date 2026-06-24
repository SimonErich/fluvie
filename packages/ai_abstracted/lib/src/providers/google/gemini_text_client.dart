import 'dart:convert';
import 'dart:typed_data';

import 'package:ai_abstracted/src/config/provider_credentials.dart';
import 'package:ai_abstracted/src/contracts/text_generator.dart';
import 'package:ai_abstracted/src/core/ai_exception.dart';
import 'package:ai_abstracted/src/core/generation_metadata.dart';
import 'package:ai_abstracted/src/core/generation_progress.dart';
import 'package:ai_abstracted/src/core/generation_result.dart';
import 'package:ai_abstracted/src/core/media_kind.dart';
import 'package:ai_abstracted/src/core/requests/text_request.dart';
import 'package:ai_abstracted/src/core/text_message.dart';
import 'package:ai_abstracted/src/providers/google/gemini_parts.dart';
import 'package:ai_abstracted/src/transport/json_http.dart';
import 'package:ai_abstracted/src/transport/retry_policy.dart';
import 'package:ai_abstracted/src/transport/retrying_http.dart';
import 'package:http/http.dart' as http;

/// The default Gemini text model.
const _defaultModel = 'gemini-2.5-flash';

/// Gemini text generation over the `generateContent` REST endpoint.
final class GeminiTextClient implements TextGenerator {
  /// Creates a [GeminiTextClient].
  GeminiTextClient({
    required this.credentials,
    http.Client? httpClient,
    this.retryPolicy = const RetryPolicy(),
    this.endpoint,
    this.sleep = Future.delayed,
  }) : _http = httpClient ?? http.Client();

  /// The provider credentials carrying the API key.
  final ProviderCredentials credentials;

  /// The retry policy applied to each request.
  final RetryPolicy retryPolicy;

  /// An optional endpoint override; defaults to the public Gemini host.
  final Uri? endpoint;

  /// The sleep seam used between retries (injected for tests).
  final Future<void> Function(Duration) sleep;

  final http.Client _http;

  static const _provider = 'gemini';

  @override
  Future<GenerationResult> generateText(
    TextRequest request, {
    void Function(GenerationProgress)? onProgress,
  }) async {
    final model = request.model ?? _defaultModel;
    final uri = _uri(model);
    onProgress?.call(const GenerationProgress(stage: GenerationStage.running));
    final json = await withRetry(
      retryPolicy,
      () => postJson(_http, uri, headers: const {}, body: _body(request), provider: _provider),
      sleep: sleep,
    );
    final text = firstText(json);
    if (text == null) {
      throw AiResponseException('Gemini returned no text part', provider: _provider);
    }
    onProgress?.call(const GenerationProgress(stage: GenerationStage.done));
    return GenerationResult(
      bytes: Uint8List.fromList(utf8.encode(text)),
      mimeType: 'text/plain',
      kind: MediaKind.text,
      metadata: GenerationMetadata(model: model),
      seedUsed: request.seed,
    );
  }

  Map<String, Object?> _body(TextRequest request) {
    final config = <String, Object?>{'maxOutputTokens': request.maxTokens};
    if (request.temperature != null) {
      config['temperature'] = request.temperature;
    }
    if (request.jsonSchema != null) {
      config['responseMimeType'] = 'application/json';
    }
    final body = <String, Object?>{
      'contents': [
        for (final turn in request.history) _historyTurn(turn),
        _finalTurn(request),
      ],
      'generationConfig': config,
    };
    if (request.system != null) {
      body['systemInstruction'] = {
        'parts': [
          {'text': request.system},
        ],
      };
    }
    return body;
  }

  Map<String, Object?> _historyTurn(TextMessage turn) => {
    'role': turn.role == TextRole.assistant ? 'model' : 'user',
    'parts': [
      {'text': turn.text},
    ],
  };

  Map<String, Object?> _finalTurn(TextRequest request) {
    final image = request.image;
    return {
      'role': 'user',
      'parts': [
        {'text': request.prompt},
        if (image != null)
          {
            'inlineData': {'mimeType': image.mimeType, 'data': base64Encode(image.bytes)},
          },
      ],
    };
  }

  Uri _uri(String model) {
    final base =
        endpoint ??
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent');
    return base.replace(queryParameters: {...base.queryParameters, 'key': credentials.apiKey});
  }
}
