import 'dart:typed_data';

import 'package:ai_abstracted/src/contracts/sound_effect_generator.dart';
import 'package:ai_abstracted/src/core/generation_metadata.dart';
import 'package:ai_abstracted/src/core/generation_progress.dart';
import 'package:ai_abstracted/src/core/generation_result.dart';
import 'package:ai_abstracted/src/core/media_kind.dart';
import 'package:ai_abstracted/src/core/requests/sound_effect_request.dart';

/// An in-memory [SoundEffectGenerator] for tests: deterministic, no network.
final class FakeSoundEffectGenerator implements SoundEffectGenerator {
  /// Creates a [FakeSoundEffectGenerator].
  ///
  /// [bytes] are returned verbatim (a tiny deterministic default otherwise),
  /// [mimeType] labels them, and [metadata] is echoed on the result.
  FakeSoundEffectGenerator({
    Uint8List? bytes,
    this.mimeType = 'audio/mpeg',
    this.metadata = const GenerationMetadata(model: 'fake-sound-effect'),
  }) : bytes = bytes ?? Uint8List.fromList(const [0x49, 0x44, 0x33, 0x03]);

  /// The audio bytes every call returns.
  final Uint8List bytes;

  /// The MIME type reported on the result.
  final String mimeType;

  /// The metadata echoed on the result.
  final GenerationMetadata metadata;

  /// The most recent request passed to [generateSoundEffect], or null before
  /// any call has been made.
  SoundEffectRequest? lastRequest;

  @override
  Future<GenerationResult> generateSoundEffect(
    SoundEffectRequest request, {
    void Function(GenerationProgress)? onProgress,
  }) async {
    lastRequest = request;
    onProgress
      ?..call(const GenerationProgress(stage: GenerationStage.queued))
      ..call(const GenerationProgress(stage: GenerationStage.running))
      ..call(const GenerationProgress(stage: GenerationStage.done));
    return GenerationResult(
      bytes: bytes,
      mimeType: mimeType,
      kind: MediaKind.soundEffect,
      metadata: metadata,
      seedUsed: request.seed,
    );
  }
}
