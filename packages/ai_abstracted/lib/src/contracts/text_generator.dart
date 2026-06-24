import 'package:ai_abstracted/src/core/generation_progress.dart';
import 'package:ai_abstracted/src/core/generation_result.dart';
import 'package:ai_abstracted/src/core/requests/text_request.dart';

/// The capability of turning a [TextRequest] into a text completion.
// One member by design: the contract is the *type*, injected where a bare
// function could not be.
// ignore: one_member_abstracts
abstract interface class TextGenerator {
  /// Generates text for [request].
  ///
  /// Calls [onProgress] with lifecycle updates when provided. The completion is
  /// returned as UTF-8 bytes in the result, with MIME type `text/plain`; read
  /// it conveniently via `GenerationResult.text`.
  Future<GenerationResult> generateText(
    TextRequest request, {
    void Function(GenerationProgress)? onProgress,
  });
}
