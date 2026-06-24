import 'package:ai_abstracted/src/config/provider_credentials.dart';
import 'package:ai_abstracted/src/contracts/music_generator.dart';
import 'package:ai_abstracted/src/core/ai_exception.dart';
import 'package:ai_abstracted/src/core/generation_metadata.dart';
import 'package:ai_abstracted/src/core/generation_progress.dart';
import 'package:ai_abstracted/src/core/generation_result.dart';
import 'package:ai_abstracted/src/core/media_kind.dart';
import 'package:ai_abstracted/src/core/requests/music_request.dart';
import 'package:ai_abstracted/src/providers/suno/suno_record.dart';
import 'package:ai_abstracted/src/transport/binary_http.dart';
import 'package:ai_abstracted/src/transport/json_http.dart';
import 'package:ai_abstracted/src/transport/poller.dart';
import 'package:ai_abstracted/src/transport/retry_policy.dart';
import 'package:ai_abstracted/src/transport/retrying_http.dart';
import 'package:http/http.dart' as http;

/// Suno music generation: submit a task, poll a record, then download.
final class SunoMusicClient implements MusicGenerator {
  /// Creates a [SunoMusicClient].
  SunoMusicClient({
    required this.credentials,
    http.Client? httpClient,
    this.retryPolicy = const RetryPolicy(),
    this.endpoint,
    this.sleep = Future.delayed,
    this.pollInterval = const Duration(seconds: 5),
    this.pollTimeout = const Duration(minutes: 5),
  }) : _http = httpClient ?? http.Client();

  /// The provider credentials carrying the API key.
  final ProviderCredentials credentials;

  /// The retry policy applied to each request.
  final RetryPolicy retryPolicy;

  /// An optional submit endpoint override; defaults to the public Suno host.
  final Uri? endpoint;

  /// The sleep seam used for retries and polling (injected for tests).
  final Future<void> Function(Duration) sleep;

  /// How often the record is polled while it generates.
  final Duration pollInterval;

  /// How long to poll before raising an [AiTimeoutException].
  final Duration pollTimeout;

  final http.Client _http;

  static const _provider = 'suno';
  static const _host = 'https://api.sunoapi.org/api/v1';

  Map<String, String> get _headers => {'authorization': 'Bearer ${credentials.apiKey}'};

  @override
  Future<GenerationResult> generateMusic(
    MusicRequest request, {
    void Function(GenerationProgress)? onProgress,
  }) async {
    final submit = await withRetry(
      retryPolicy,
      () => postJson(
        _http,
        endpoint ?? Uri.parse('$_host/generate'),
        headers: _headers,
        body: _body(request),
        provider: _provider,
      ),
      sleep: sleep,
    );
    final taskId = sunoTaskId(submit);
    if (taskId == null) {
      throw AiResponseException('Suno did not return a task id', provider: _provider);
    }

    final audioUrl = await pollUntil<String>(
      poll: () => _pollRecord(taskId),
      interval: pollInterval,
      timeout: pollTimeout,
      onProgress: onProgress,
      sleep: sleep,
      provider: _provider,
    );

    onProgress?.call(const GenerationProgress(stage: GenerationStage.downloading));
    final audio = await withRetry(
      retryPolicy,
      () => getBytes(_http, Uri.parse(audioUrl), provider: _provider),
      sleep: sleep,
    );
    onProgress?.call(const GenerationProgress(stage: GenerationStage.done));
    return GenerationResult(
      bytes: audio.bytes,
      mimeType: audio.mimeType,
      kind: MediaKind.music,
      metadata: GenerationMetadata(model: request.model ?? 'suno', providerJobId: taskId),
      seedUsed: request.seed,
    );
  }

  Map<String, Object?> _body(MusicRequest request) => {
    'prompt': request.prompt,
    'instrumental': request.instrumental,
    'customMode': false,
    if (request.style != null) 'style': request.style,
    if (request.title != null) 'title': request.title,
    if (request.model != null) 'model': request.model,
  };

  /// Polls the record once; returns the first audio URL, else null.
  Future<String?> _pollRecord(String taskId) async {
    final json = await withRetry(
      retryPolicy,
      () => getJson(
        _http,
        Uri.parse('$_host/generate/record-info?taskId=$taskId'),
        headers: _headers,
        provider: _provider,
      ),
      sleep: sleep,
    );
    return sunoAudioUrl(json);
  }
}
