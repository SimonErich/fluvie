import 'package:ai_abstracted/src/core/generation_progress.dart';
import 'package:ai_abstracted/src/core/generation_result.dart';
import 'package:ai_abstracted/src/core/requests/image_request.dart';

/// The capability of turning an [ImageRequest] into image bytes.
// One member by design: the contract is the *type*, injected where a bare
// function could not be.
// ignore: one_member_abstracts
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
