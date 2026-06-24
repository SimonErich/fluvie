import 'dart:typed_data';

import 'package:ai_abstracted/src/contracts/music_generator.dart';
import 'package:ai_abstracted/src/core/generation_metadata.dart';
import 'package:ai_abstracted/src/core/generation_progress.dart';
import 'package:ai_abstracted/src/core/generation_result.dart';
import 'package:ai_abstracted/src/core/media_kind.dart';
import 'package:ai_abstracted/src/core/requests/music_request.dart';

/// An in-memory [MusicGenerator] for tests: no network, deterministic bytes.
final class FakeMusicGenerator implements MusicGenerator {
  /// Creates a [FakeMusicGenerator].
  ///
  /// [bytes] are returned verbatim (a tiny deterministic default otherwise),
  /// [mimeType] labels them, and [metadata] is echoed on the result.
  FakeMusicGenerator({
    Uint8List? bytes,
    this.mimeType = 'audio/mpeg',
    this.metadata = const GenerationMetadata(model: 'fake-music'),
  }) : bytes = bytes ?? Uint8List.fromList(const [0x49, 0x44, 0x33, 0x02]);

  /// The audio bytes every call returns.
  final Uint8List bytes;

  /// The MIME type reported on the result.
  final String mimeType;

  /// The metadata echoed on the result.
  final GenerationMetadata metadata;

  /// The most recent request passed to [generateMusic], or null before any.
  MusicRequest? lastRequest;

  @override
  Future<GenerationResult> generateMusic(
    MusicRequest request, {
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
      kind: MediaKind.music,
      metadata: metadata,
      seedUsed: request.seed,
    );
  }
}
