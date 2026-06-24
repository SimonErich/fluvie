import 'package:ai_abstracted/src/core/generation_progress.dart';
import 'package:ai_abstracted/src/core/generation_result.dart';
import 'package:ai_abstracted/src/core/requests/sound_effect_request.dart';

/// The capability of turning a [SoundEffectRequest] into sound-effect bytes.
// One member by design: the contract is the *type*, injected where a bare
// function could not be.
// ignore: one_member_abstracts
abstract interface class SoundEffectGenerator {
  /// Generates a sound effect for [request].
  ///
  /// Calls [onProgress] with lifecycle updates when provided. Completes with a
  /// [GenerationResult] whose bytes are the encoded audio.
  Future<GenerationResult> generateSoundEffect(
    SoundEffectRequest request, {
    void Function(GenerationProgress)? onProgress,
  });
}
