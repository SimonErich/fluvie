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
import 'package:ai_abstracted/src/transport/json_http.dart';
import 'package:ai_abstracted/src/transport/retry_policy.dart';
import 'package:ai_abstracted/src/transport/retrying_http.dart';
import 'package:http/http.dart' as http;

/// The default Mistral text model.
const _defaultModel = 'mistral-large-latest';

/// Mistral text generation over the OpenAI-style `/v1/chat/completions` API.
final class MistralTextClient implements TextGenerator {
  /// Creates a [MistralTextClient].
  MistralTextClient({
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

  /// An optional endpoint override; defaults to the public Mistral host.
  final Uri? endpoint;

  /// The sleep seam used between retries (injected for tests).
  final Future<void> Function(Duration) sleep;

  final http.Client _http;

  static const _provider = 'mistral';

  @override
  Future<GenerationResult> generateText(
    TextRequest request, {
    void Function(GenerationProgress)? onProgress,
  }) async {
    final model = request.model ?? _defaultModel;
    onProgress?.call(const GenerationProgress(stage: GenerationStage.running));
    final json = await withRetry(
      retryPolicy,
      () => postJson(
        _http,
        endpoint ?? Uri.parse('https://api.mistral.ai/v1/chat/completions'),
        headers: {'authorization': 'Bearer ${credentials.apiKey}'},
        body: _body(request, model),
        provider: _provider,
      ),
      sleep: sleep,
    );
    final text = _firstContent(json);
    if (text == null) {
      throw AiResponseException('Mistral returned no message content', provider: _provider);
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

  Map<String, Object?> _body(TextRequest request, String model) => {
    'model': model,
    'max_tokens': request.maxTokens,
    if (request.temperature != null) 'temperature': request.temperature,
    if (request.jsonSchema != null) 'response_format': {'type': 'json_object'},
    'messages': [
      if (request.system != null) {'role': 'system', 'content': request.system},
      for (final turn in request.history)
        {'role': turn.role == TextRole.assistant ? 'assistant' : 'user', 'content': turn.text},
      {'role': 'user', 'content': request.prompt},
    ],
  };

  String? _firstContent(Map<String, Object?> json) {
    final choices = json['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map<String, Object?>) {
      return null;
    }
    final message = (choices.first as Map<String, Object?>)['message'];
    if (message is Map<String, Object?> && message['content'] is String) {
      return message['content']! as String;
    }
    return null;
  }
}
