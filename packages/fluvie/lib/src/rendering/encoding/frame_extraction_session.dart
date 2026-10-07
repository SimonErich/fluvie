import 'package:fluvie/src/rendering/capture/raw_frame.dart';

/// Optional lease factory for decoders that retain source position across batches.
// ignore: one_member_abstracts — extractor implementations advertise this optional lifecycle capability.
abstract interface class FrameExtractionSessionService {
  /// Opens one caller-owned source decoder with a fixed output raster.
  /// The cancellation future terminates pending decode work when supported.
  Future<FrameExtractionSession> openSession(
    Uri source, {
    required int width,
    required int height,
    String? decoder,
    Future<void>? whenCancelled,
  });
}

/// One source decoder retained by a media repository until resource release.
abstract interface class FrameExtractionSession {
  /// Reads source ordinals while reusing previous sequential decode work.
  Future<Map<int, RawFrame>> extractFrames(Iterable<int> frameIndices);

  /// Terminates native work and releases the decoder. Idempotent.
  Future<void> close();
}
