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
import 'package:ai_abstracted/src/transport/poller.dart';
import 'package:ai_abstracted/src/transport/retry_policy.dart';
import 'package:ai_abstracted/src/transport/retrying_http.dart';
import 'package:http/http.dart' as http;

/// The default Black Forest Labs FLUX model.
const _defaultModel = 'flux-pro-1.1';

/// FLUX image generation: a submit, then a poll-until-Ready, then a download.
final class FluxImageClient implements ImageGenerator {
  /// Creates a [FluxImageClient].
  FluxImageClient({
    required this.credentials,
    http.Client? httpClient,
    this.retryPolicy = const RetryPolicy(),
    this.endpoint,
    this.sleep = Future.delayed,
    this.pollInterval = const Duration(seconds: 2),
    this.pollTimeout = const Duration(minutes: 3),
  }) : _http = httpClient ?? http.Client();

  /// The provider credentials carrying the API key.
  final ProviderCredentials credentials;

  /// The retry policy applied to each request.
  final RetryPolicy retryPolicy;

  /// An optional submit endpoint override; defaults to the public FLUX host.
  final Uri? endpoint;

  /// The sleep seam used for retries and polling (injected for tests).
  final Future<void> Function(Duration) sleep;

  /// How often the job is polled while it runs.
  final Duration pollInterval;

  /// How long to poll before raising an [AiTimeoutException].
  final Duration pollTimeout;

  final http.Client _http;

  static const _provider = 'flux';

  Map<String, String> get _headers => {'x-key': credentials.apiKey};

  @override
  Future<GenerationResult> generateImage(
    ImageRequest request, {
    void Function(GenerationProgress)? onProgress,
  }) async {
    final model = request.model ?? _defaultModel;
    final submit = await withRetry(
      retryPolicy,
      () => postJson(
        _http,
        endpoint ?? Uri.parse('https://api.bfl.ml/v1/$model'),
        headers: _headers,
        body: _body(request),
        provider: _provider,
      ),
      sleep: sleep,
    );
    final pollingUrl = submit['polling_url'];
    if (pollingUrl is! String) {
      throw AiResponseException('FLUX did not return a polling_url', provider: _provider);
    }

    final ready = await pollUntil<Map<String, Object?>>(
      poll: () => _pollResult(pollingUrl),
      interval: pollInterval,
      timeout: pollTimeout,
      onProgress: onProgress,
      sleep: sleep,
      provider: _provider,
    );

    onProgress?.call(const GenerationProgress(stage: GenerationStage.downloading));
    final bytes = await _downloadSample(ready);
    onProgress?.call(const GenerationProgress(stage: GenerationStage.done));
    return GenerationResult(
      bytes: bytes.bytes,
      mimeType: bytes.mimeType,
      kind: MediaKind.image,
      metadata: GenerationMetadata(
        model: model,
        width: request.width,
        height: request.height,
        providerJobId: submit['id'] is String ? submit['id']! as String : null,
      ),
      seedUsed: request.seed,
    );
  }

  Map<String, Object?> _body(ImageRequest request) {
    final body = <String, Object?>{'prompt': request.prompt};
    if (request.width != null) {
      body['width'] = request.width;
    }
    if (request.height != null) {
      body['height'] = request.height;
    }
    if (request.aspectRatio != null) {
      body['aspect_ratio'] = request.aspectRatio;
    }
    return body;
  }

  /// Polls the result once; returns the result map when Ready, else null.
  Future<Map<String, Object?>?> _pollResult(String pollingUrl) async {
    final json = await withRetry(
      retryPolicy,
      () => getJson(_http, Uri.parse(pollingUrl), headers: _headers, provider: _provider),
      sleep: sleep,
    );
    final status = json['status'];
    final ready = status == 'Ready' || status == 'SUCCESS';
    return ready ? json : null;
  }

  Future<BinaryResponse> _downloadSample(Map<String, Object?> ready) async {
    final result = ready['result'];
    final sample = result is Map<String, Object?> ? result['sample'] : null;
    if (sample is! String) {
      throw AiResponseException('FLUX result carried no sample url', provider: _provider);
    }
    return withRetry(
      retryPolicy,
      () => getBytes(_http, Uri.parse(sample), provider: _provider),
      sleep: sleep,
    );
  }
}
