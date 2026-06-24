import 'dart:typed_data';

import 'package:ai_abstracted/src/contracts/video_generator.dart';
import 'package:ai_abstracted/src/core/generation_metadata.dart';
import 'package:ai_abstracted/src/core/generation_progress.dart';
import 'package:ai_abstracted/src/core/generation_result.dart';
import 'package:ai_abstracted/src/core/media_kind.dart';
import 'package:ai_abstracted/src/core/requests/video_request.dart';

/// An in-memory [VideoGenerator] for tests: no network, deterministic bytes.
final class FakeVideoGenerator implements VideoGenerator {
  /// Creates a [FakeVideoGenerator].
  ///
  /// [bytes] are returned verbatim (a tiny deterministic default otherwise),
  /// [mimeType] labels them, and [metadata] is echoed on the result (it reports
  /// `hasAudio: true` by default, mirroring an audio-capable model).
  FakeVideoGenerator({
    Uint8List? bytes,
    this.mimeType = 'video/mp4',
    this.metadata = const GenerationMetadata(model: 'fake-video', hasAudio: true),
  }) : bytes = bytes ?? Uint8List.fromList(const [0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70]);

  /// The video bytes every call returns.
  final Uint8List bytes;

  /// The MIME type reported on the result.
  final String mimeType;

  /// The metadata echoed on the result.
  final GenerationMetadata metadata;

  /// The most recent request passed to [generateVideo], or null before any.
  VideoRequest? lastRequest;

  @override
  Future<GenerationResult> generateVideo(
    VideoRequest request, {
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
      kind: MediaKind.video,
      metadata: metadata,
      seedUsed: request.seed,
    );
  }
}
