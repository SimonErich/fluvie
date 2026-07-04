import 'package:ai_abstracted/src/core/generation_progress.dart';
import 'package:ai_abstracted/src/core/generation_result.dart';
import 'package:ai_abstracted/src/core/requests/speech_request.dart';

/// The capability of turning a [SpeechRequest] into spoken audio bytes.
// ignore: one_member_abstracts — the contract is the type: injectable where a bare function isn't.
abstract interface class SpeechGenerator {
  /// Synthesizes speech for [request].
  ///
  /// Calls [onProgress] with lifecycle updates when provided. Completes with a
  /// [GenerationResult] whose bytes are the encoded audio.
  Future<GenerationResult> generateSpeech(
    SpeechRequest request, {
    void Function(GenerationProgress)? onProgress,
  });
}
