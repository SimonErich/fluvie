import 'package:ai_abstracted/src/core/generation_progress.dart';
import 'package:ai_abstracted/src/core/generation_result.dart';
import 'package:ai_abstracted/src/core/requests/text_request.dart';

/// The capability of turning a [TextRequest] into a text completion.
// ignore: one_member_abstracts — the contract is the type: injectable where a bare function isn't.
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
