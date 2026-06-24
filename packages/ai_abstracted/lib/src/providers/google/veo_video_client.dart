import 'dart:convert';
import 'dart:typed_data';

import 'package:ai_abstracted/src/config/provider_credentials.dart';
import 'package:ai_abstracted/src/contracts/video_generator.dart';
import 'package:ai_abstracted/src/core/ai_exception.dart';
import 'package:ai_abstracted/src/core/generation_metadata.dart';
import 'package:ai_abstracted/src/core/generation_progress.dart';
import 'package:ai_abstracted/src/core/generation_result.dart';
import 'package:ai_abstracted/src/core/media_kind.dart';
import 'package:ai_abstracted/src/core/requests/video_request.dart';
import 'package:ai_abstracted/src/providers/google/veo_operation.dart';
import 'package:ai_abstracted/src/transport/binary_http.dart';
import 'package:ai_abstracted/src/transport/json_http.dart';
import 'package:ai_abstracted/src/transport/poller.dart';
import 'package:ai_abstracted/src/transport/retry_policy.dart';
import 'package:ai_abstracted/src/transport/retrying_http.dart';
import 'package:http/http.dart' as http;

/// The default Veo model; Veo 3 carries an audio track.
const _defaultModel = 'veo-3.0-generate-001';

/// Google Veo video generation: a long-running predict job, then a download.
final class VeoVideoClient implements VideoGenerator {
  /// Creates a [VeoVideoClient].
  VeoVideoClient({
    required this.credentials,
    http.Client? httpClient,
    this.retryPolicy = const RetryPolicy(),
    this.endpoint,
    this.sleep = Future.delayed,
    this.pollInterval = const Duration(seconds: 10),
    this.pollTimeout = const Duration(minutes: 10),
  }) : _http = httpClient ?? http.Client();

  /// The provider credentials carrying the API key.
  final ProviderCredentials credentials;

  /// The retry policy applied to each request.
  final RetryPolicy retryPolicy;

  /// An optional endpoint override; defaults to the public Gemini host.
  final Uri? endpoint;

  /// The sleep seam used for retries and polling (injected for tests).
  final Future<void> Function(Duration) sleep;

  /// How often the operation is polled while it runs.
  final Duration pollInterval;

  /// How long to poll before raising an [AiTimeoutException].
  final Duration pollTimeout;

  final http.Client _http;

  static const _provider = 'veo';
  static const _host = 'https://generativelanguage.googleapis.com/v1beta';

  Map<String, String> get _authHeaders => {'x-goog-api-key': credentials.apiKey};

  @override
  Future<GenerationResult> generateVideo(
    VideoRequest request, {
    void Function(GenerationProgress)? onProgress,
  }) async {
    final model = request.model ?? _defaultModel;
    final start = await withRetry(
      retryPolicy,
      () => postJson(
        _http,
        endpoint ?? Uri.parse('$_host/models/$model:predictLongRunning'),
        headers: _authHeaders,
        body: _startBody(request),
        provider: _provider,
      ),
      sleep: sleep,
    );
    final operationName = start['name'];
    if (operationName is! String) {
      throw AiResponseException('Veo did not return an operation name', provider: _provider);
    }

    final done = await pollUntil<Map<String, Object?>>(
      poll: () => _pollOperation(operationName),
      interval: pollInterval,
      timeout: pollTimeout,
      onProgress: onProgress,
      sleep: sleep,
      provider: _provider,
    );

    onProgress?.call(const GenerationProgress(stage: GenerationStage.downloading));
    final bytes = await _downloadVideo(done);
    onProgress?.call(const GenerationProgress(stage: GenerationStage.done));
    return GenerationResult(
      bytes: bytes,
      mimeType: 'video/mp4',
      kind: MediaKind.video,
      metadata: GenerationMetadata(
        model: model,
        hasAudio: request.withAudio,
        width: request.width,
        height: request.height,
        providerJobId: operationName,
      ),
      seedUsed: request.seed,
    );
  }

  Map<String, Object?> _startBody(VideoRequest request) {
    final params = <String, Object?>{};
    if (request.aspectRatio != null) {
      params['aspectRatio'] = request.aspectRatio;
    }
    return {
      'instances': [
        {'prompt': request.prompt},
      ],
      if (params.isNotEmpty) 'parameters': params,
    };
  }

  /// Polls the operation once; returns the operation map when done, else null.
  Future<Map<String, Object?>?> _pollOperation(String operationName) async {
    final json = await withRetry(
      retryPolicy,
      () => getJson(
        _http,
        Uri.parse('$_host/$operationName'),
        headers: _authHeaders,
        provider: _provider,
      ),
      sleep: sleep,
    );
    return json['done'] == true ? json : null;
  }

  Future<Uint8List> _downloadVideo(Map<String, Object?> operation) async {
    final sample = veoSample(operation);
    if (sample == null) {
      throw AiResponseException('Veo operation carried no video sample', provider: _provider);
    }
    if (sample.inlineBase64 != null) {
      return Uint8List.fromList(base64Decode(sample.inlineBase64!));
    }
    final download = await withRetry(
      retryPolicy,
      () => getBytes(_http, Uri.parse(sample.uri!), headers: _authHeaders, provider: _provider),
      sleep: sleep,
    );
    return download.bytes;
  }
}
