import 'package:ai_abstracted/src/core/generation_progress.dart';
import 'package:ai_abstracted/src/core/generation_result.dart';
import 'package:ai_abstracted/src/core/requests/music_request.dart';

/// The capability of turning a [MusicRequest] into music bytes.
// ignore: one_member_abstracts — the contract is the type: injectable where a bare function isn't.
abstract interface class MusicGenerator {
  /// Generates a music track for [request].
  ///
  /// Calls [onProgress] with lifecycle updates when provided. Completes with a
  /// [GenerationResult] whose bytes are the encoded audio.
  Future<GenerationResult> generateMusic(
    MusicRequest request, {
    void Function(GenerationProgress)? onProgress,
  });
}
