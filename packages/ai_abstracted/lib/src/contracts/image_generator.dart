import 'package:ai_abstracted/src/core/generation_progress.dart';
import 'package:ai_abstracted/src/core/generation_result.dart';
import 'package:ai_abstracted/src/core/requests/image_request.dart';

/// The capability of turning an [ImageRequest] into image bytes.
// ignore: one_member_abstracts — the contract is the type: injectable where a bare function isn't.
abstract interface class ImageGenerator {
  /// Generates an image for [request].
  ///
  /// Calls [onProgress] with lifecycle updates when provided. Completes with a
  /// [GenerationResult] whose bytes are the encoded image.
  Future<GenerationResult> generateImage(
    ImageRequest request, {
    void Function(GenerationProgress)? onProgress,
  });
}
