import 'dart:convert';
import 'dart:typed_data';

import 'package:ai_abstracted/src/config/provider_credentials.dart';
import 'package:ai_abstracted/src/contracts/image_generator.dart';
import 'package:ai_abstracted/src/core/ai_exception.dart';
import 'package:ai_abstracted/src/core/generation_metadata.dart';
import 'package:ai_abstracted/src/core/generation_progress.dart';
import 'package:ai_abstracted/src/core/generation_result.dart';
import 'package:ai_abstracted/src/core/media_kind.dart';
import 'package:ai_abstracted/src/core/requests/image_request.dart';
import 'package:ai_abstracted/src/transport/binary_http.dart';
import 'package:ai_abstracted/src/transport/json_http.dart';
import 'package:ai_abstracted/src/transport/retry_policy.dart';
import 'package:ai_abstracted/src/transport/retrying_http.dart';
import 'package:http/http.dart' as http;

/// The default OpenAI image model.
const _defaultModel = 'gpt-image-1';

/// OpenAI image generation over the `/v1/images/generations` endpoint.
final class OpenAiImageClient implements ImageGenerator {
  /// Creates an [OpenAiImageClient].
  OpenAiImageClient({
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

  /// An optional endpoint override; defaults to the public OpenAI host.
  final Uri? endpoint;

  /// The sleep seam used between retries (injected for tests).
  final Future<void> Function(Duration) sleep;

  final http.Client _http;

  static const _provider = 'openai';

  Map<String, String> get _headers => {
    'authorization': 'Bearer ${credentials.apiKey}',
    if (credentials.organization != null) 'openai-organization': credentials.organization!,
  };

  @override
  Future<GenerationResult> generateImage(
    ImageRequest request, {
    void Function(GenerationProgress)? onProgress,
  }) async {
    final model = request.model ?? _defaultModel;
    onProgress?.call(const GenerationProgress(stage: GenerationStage.running));
    final json = await withRetry(
      retryPolicy,
      () => postJson(
        _http,
        endpoint ?? Uri.parse('https://api.openai.com/v1/images/generations'),
        headers: _headers,
        body: _body(request, model),
        provider: _provider,
      ),
      sleep: sleep,
    );

    final entry = _firstData(json);
    final result = await _bytesFrom(entry);
    onProgress?.call(const GenerationProgress(stage: GenerationStage.done));
    return GenerationResult(
      bytes: result.bytes,
      mimeType: result.mimeType,
      kind: MediaKind.image,
      metadata: GenerationMetadata(model: model, width: request.width, height: request.height),
      seedUsed: request.seed,
    );
  }

  Map<String, Object?> _body(ImageRequest request, String model) {
    final body = <String, Object?>{'model': model, 'prompt': request.prompt, 'n': 1};
    if (request.width != null && request.height != null) {
      body['size'] = '${request.width}x${request.height}';
    }
    return body;
  }

  Map<String, Object?> _firstData(Map<String, Object?> json) {
    final data = json['data'];
    if (data is! List || data.isEmpty || data.first is! Map<String, Object?>) {
      throw AiResponseException('OpenAI returned no image data', provider: _provider);
    }
    return data.first as Map<String, Object?>;
  }

  Future<BinaryResponse> _bytesFrom(Map<String, Object?> entry) async {
    final b64 = entry['b64_json'];
    if (b64 is String) {
      return (bytes: Uint8List.fromList(base64Decode(b64)), mimeType: 'image/png');
    }
    final url = entry['url'];
    if (url is String) {
      return withRetry(
        retryPolicy,
        () => getBytes(_http, Uri.parse(url), provider: _provider),
        sleep: sleep,
      );
    }
    throw AiResponseException('OpenAI image entry had no bytes or url', provider: _provider);
  }
}
