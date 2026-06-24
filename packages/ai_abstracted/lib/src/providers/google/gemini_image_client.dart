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
import 'package:ai_abstracted/src/providers/google/gemini_parts.dart';
import 'package:ai_abstracted/src/transport/json_http.dart';
import 'package:ai_abstracted/src/transport/retry_policy.dart';
import 'package:ai_abstracted/src/transport/retrying_http.dart';
import 'package:http/http.dart' as http;

/// The default Gemini image model ("Nano Banana").
const _defaultModel = 'gemini-2.5-flash-image';

/// Gemini image generation over the `generateContent` REST endpoint.
final class GeminiImageClient implements ImageGenerator {
  /// Creates a [GeminiImageClient].
  GeminiImageClient({
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
  Future<GenerationResult> generateImage(
    ImageRequest request, {
    void Function(GenerationProgress)? onProgress,
  }) async {
    final model = request.model ?? _defaultModel;
    final uri = _uri(model);
    onProgress?.call(const GenerationProgress(stage: GenerationStage.running));
    final json = await withRetry(
      retryPolicy,
      () => postJson(
        _http,
        uri,
        headers: const {},
        body: {
          'contents': [
            {
              'parts': [
                {'text': request.prompt},
              ],
            },
          ],
        },
        provider: _provider,
      ),
      sleep: sleep,
    );
    final inline = firstInlineData(json);
    if (inline == null) {
      throw AiResponseException(
        'Gemini returned no inline image data',
        provider: _provider,
      );
    }
    onProgress?.call(const GenerationProgress(stage: GenerationStage.done));
    return GenerationResult(
      bytes: Uint8List.fromList(base64Decode(inline.data)),
      mimeType: inline.mimeType,
      kind: MediaKind.image,
      metadata: GenerationMetadata(model: model, width: request.width, height: request.height),
      seedUsed: request.seed,
    );
  }

  Uri _uri(String model) {
    final base =
        endpoint ??
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent');
    return base.replace(queryParameters: {...base.queryParameters, 'key': credentials.apiKey});
  }
}
