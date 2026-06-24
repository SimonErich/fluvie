import 'package:ai_abstracted/src/config/provider_credentials.dart';
import 'package:ai_abstracted/src/contracts/sound_effect_generator.dart';
import 'package:ai_abstracted/src/core/generation_metadata.dart';
import 'package:ai_abstracted/src/core/generation_progress.dart';
import 'package:ai_abstracted/src/core/generation_result.dart';
import 'package:ai_abstracted/src/core/media_kind.dart';
import 'package:ai_abstracted/src/core/requests/sound_effect_request.dart';
import 'package:ai_abstracted/src/transport/binary_http.dart';
import 'package:ai_abstracted/src/transport/retry_policy.dart';
import 'package:ai_abstracted/src/transport/retrying_http.dart';
import 'package:http/http.dart' as http;

/// ElevenLabs sound-effect synthesis: a JSON POST that answers with audio.
final class ElevenLabsSoundEffectClient implements SoundEffectGenerator {
  /// Creates an [ElevenLabsSoundEffectClient].
  ElevenLabsSoundEffectClient({
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

  /// An optional endpoint override; defaults to the public ElevenLabs host.
  final Uri? endpoint;

  /// The sleep seam used between retries (injected for tests).
  final Future<void> Function(Duration) sleep;

  final http.Client _http;

  static const _provider = 'elevenlabs';

  @override
  Future<GenerationResult> generateSoundEffect(
    SoundEffectRequest request, {
    void Function(GenerationProgress)? onProgress,
  }) async {
    onProgress?.call(const GenerationProgress(stage: GenerationStage.running));
    final audio = await withRetry(
      retryPolicy,
      () => postForBytes(
        _http,
        endpoint ?? Uri.parse('https://api.elevenlabs.io/v1/sound-generation'),
        headers: {'xi-api-key': credentials.apiKey},
        body: _body(request),
        provider: _provider,
      ),
      sleep: sleep,
    );
    onProgress?.call(const GenerationProgress(stage: GenerationStage.done));
    return GenerationResult(
      bytes: audio.bytes,
      mimeType: audio.mimeType,
      kind: MediaKind.soundEffect,
      metadata: const GenerationMetadata(model: 'eleven-sound-effects'),
      seedUsed: request.seed,
    );
  }

  Map<String, Object?> _body(SoundEffectRequest request) => {
    'text': request.prompt,
    if (request.seconds != null) 'duration_seconds': request.seconds,
    if (request.promptInfluence != null) 'prompt_influence': request.promptInfluence,
  };
}
