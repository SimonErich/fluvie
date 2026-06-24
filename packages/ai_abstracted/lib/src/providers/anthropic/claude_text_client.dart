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

/// The default Anthropic Claude text model.
const _defaultModel = 'claude-opus-4-8';

/// Anthropic Claude text generation over the `/v1/messages` endpoint.
final class ClaudeTextClient implements TextGenerator {
  /// Creates a [ClaudeTextClient].
  ClaudeTextClient({
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

  /// An optional endpoint override; defaults to the public Anthropic host.
  final Uri? endpoint;

  /// The sleep seam used between retries (injected for tests).
  final Future<void> Function(Duration) sleep;

  final http.Client _http;

  static const _provider = 'claude';

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
        endpoint ?? Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {'x-api-key': credentials.apiKey, 'anthropic-version': '2023-06-01'},
        body: _body(request, model),
        provider: _provider,
      ),
      sleep: sleep,
    );
    if (json['stop_reason'] == 'refusal') {
      throw AiResponseException('Claude declined', provider: _provider);
    }
    final text = _firstText(json);
    if (text == null) {
      throw AiResponseException('Claude returned no text block', provider: _provider);
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

  Map<String, Object?> _body(TextRequest request, String model) {
    final body = <String, Object?>{
      'model': model,
      'max_tokens': request.maxTokens,
      if (request.system != null) 'system': request.system,
      'messages': [
        for (final turn in request.history)
          {'role': turn.role == TextRole.assistant ? 'assistant' : 'user', 'content': turn.text},
        {'role': 'user', 'content': _finalContent(request)},
      ],
    };
    return body;
  }

  Object _finalContent(TextRequest request) {
    final image = request.image;
    if (image == null) {
      return request.prompt;
    }
    return [
      {'type': 'text', 'text': request.prompt},
      {
        'type': 'image',
        'source': {
          'type': 'base64',
          'media_type': image.mimeType,
          'data': base64Encode(image.bytes),
        },
      },
    ];
  }

  String? _firstText(Map<String, Object?> json) {
    final content = json['content'];
    if (content is! List) {
      return null;
    }
    for (final block in content) {
      if (block is Map<String, Object?> && block['type'] == 'text' && block['text'] is String) {
        return block['text']! as String;
      }
    }
    return null;
  }
}
