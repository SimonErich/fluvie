import 'package:ai_abstracted/src/core/generation_progress.dart';
import 'package:ai_abstracted/src/core/generation_result.dart';
import 'package:ai_abstracted/src/core/requests/video_request.dart';

/// The capability of turning a [VideoRequest] into video bytes.
// One member by design: the contract is the *type*, injected where a bare
// function could not be.
// ignore: one_member_abstracts
abstract interface class VideoGenerator {
  /// Generates a video for [request].
  ///
  /// Calls [onProgress] with lifecycle updates when provided. The result's
  /// `metadata.hasAudio` reports whether the clip carries an audio track (set
  /// for providers such as Veo 3).
  Future<GenerationResult> generateVideo(
    VideoRequest request, {
    void Function(GenerationProgress)? onProgress,
  });
}
