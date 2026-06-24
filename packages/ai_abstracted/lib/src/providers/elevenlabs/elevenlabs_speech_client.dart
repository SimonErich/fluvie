import 'package:ai_abstracted/src/config/provider_credentials.dart';
import 'package:ai_abstracted/src/contracts/speech_generator.dart';
import 'package:ai_abstracted/src/core/generation_metadata.dart';
import 'package:ai_abstracted/src/core/generation_progress.dart';
import 'package:ai_abstracted/src/core/generation_result.dart';
import 'package:ai_abstracted/src/core/media_kind.dart';
import 'package:ai_abstracted/src/core/requests/speech_request.dart';
import 'package:ai_abstracted/src/transport/binary_http.dart';
import 'package:ai_abstracted/src/transport/retry_policy.dart';
import 'package:ai_abstracted/src/transport/retrying_http.dart';
import 'package:http/http.dart' as http;

/// The ElevenLabs default voice id ("Rachel").
const _defaultVoice = '21m00Tcm4TlvDq8ikWAM';

/// The default ElevenLabs text-to-speech model.
const _defaultModel = 'eleven_multilingual_v2';

/// ElevenLabs text-to-speech: a JSON POST that answers with audio bytes.
final class ElevenLabsSpeechClient implements SpeechGenerator {
  /// Creates an [ElevenLabsSpeechClient].
  ElevenLabsSpeechClient({
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

  /// An optional base endpoint override; the voice id is appended to it.
  final Uri? endpoint;

  /// The sleep seam used between retries (injected for tests).
  final Future<void> Function(Duration) sleep;

  final http.Client _http;

  static const _provider = 'elevenlabs';

  @override
  Future<GenerationResult> generateSpeech(
    SpeechRequest request, {
    void Function(GenerationProgress)? onProgress,
  }) async {
    final voice = request.voice ?? _defaultVoice;
    final model = request.model ?? _defaultModel;
    onProgress?.call(const GenerationProgress(stage: GenerationStage.running));
    final audio = await withRetry(
      retryPolicy,
      () => postForBytes(
        _http,
        _uri(voice),
        headers: {'xi-api-key': credentials.apiKey},
        body: _body(request, model),
        provider: _provider,
      ),
      sleep: sleep,
    );
    onProgress?.call(const GenerationProgress(stage: GenerationStage.done));
    return GenerationResult(
      bytes: audio.bytes,
      mimeType: audio.mimeType,
      kind: MediaKind.speech,
      metadata: GenerationMetadata(model: model, extra: {'voice': voice}),
      seedUsed: request.seed,
    );
  }

  Map<String, Object?> _body(SpeechRequest request, String model) {
    final settings = <String, Object?>{};
    if (request.stability != null) {
      settings['stability'] = request.stability;
    }
    if (request.similarity != null) {
      settings['similarity_boost'] = request.similarity;
    }
    return {
      'text': request.prompt,
      'model_id': model,
      if (settings.isNotEmpty) 'voice_settings': settings,
    };
  }

  Uri _uri(String voice) => endpoint == null
      ? Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$voice')
      : endpoint!.replace(pathSegments: [...endpoint!.pathSegments, voice]);
}
