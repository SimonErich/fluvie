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

/// The default Ollama text model.
const _defaultModel = 'llama3.1';

/// Ollama local text generation over the `/api/chat` endpoint.
final class OllamaTextClient implements TextGenerator {
  /// Creates an [OllamaTextClient].
  OllamaTextClient({
    required this.credentials,
    http.Client? httpClient,
    this.retryPolicy = const RetryPolicy(),
    this.endpoint,
    this.sleep = Future.delayed,
  }) : _http = httpClient ?? http.Client();

  /// The provider credentials; [ProviderCredentials.apiKey] may be empty.
  final ProviderCredentials credentials;

  /// The retry policy applied to each request.
  final RetryPolicy retryPolicy;

  /// An optional endpoint override; defaults to the local Ollama host.
  final Uri? endpoint;

  /// The sleep seam used between retries (injected for tests).
  final Future<void> Function(Duration) sleep;

  final http.Client _http;

  static const _provider = 'ollama';

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
        _uri(),
        headers: const {},
        body: _body(request, model),
        provider: _provider,
      ),
      sleep: sleep,
    );
    final text = _firstContent(json);
    if (text == null) {
      throw AiResponseException('Ollama returned no message content', provider: _provider);
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

  Uri _uri() {
    if (endpoint != null) {
      return endpoint!;
    }
    final base = credentials.baseUrl;
    if (base != null) {
      return base.replace(path: '/api/chat');
    }
    return Uri.parse('http://localhost:11434/api/chat');
  }

  Map<String, Object?> _body(TextRequest request, String model) => {
    'model': model,
    'stream': false,
    if (request.jsonSchema != null) 'format': 'json',
    'options': {if (request.temperature != null) 'temperature': request.temperature},
    'messages': [
      if (request.system != null) {'role': 'system', 'content': request.system},
      for (final turn in request.history)
        {'role': turn.role == TextRole.assistant ? 'assistant' : 'user', 'content': turn.text},
      {'role': 'user', 'content': request.prompt},
    ],
  };

  String? _firstContent(Map<String, Object?> json) {
    final message = json['message'];
    if (message is Map<String, Object?> && message['content'] is String) {
      return message['content']! as String;
    }
    return null;
  }
}
