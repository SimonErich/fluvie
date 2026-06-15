import 'package:fluvie/src/rendering/capture/raw_frame.dart';

/// Extracts one decoded frame of a video source as a [RawFrame].
///
/// This is the contract the `Clip` render path consumes: during capture, a
/// clip's pixels for frame *n* come from here instead of from a live player.
/// Tests run against a canned fake; the ffmpeg-backed service supplies the
/// pixels at render.
// One member by design: the contract is the *type* — a canned fake in tests
// and the ffmpeg-backed service at render are injected where a bare function
// could not be.
// ignore: one_member_abstracts
abstract interface class FrameExtractionService {
  /// The decoded pixels of [source] at [frameIndex] (in the source's own
  /// frame space), scaled to exactly [width] x [height].
  ///
  /// The caller pins the output size (from a prior probe) so the returned
  /// [RawFrame] always holds `width * height * 4` bytes — deterministic and
  /// directly compositable. Throws a `FluvieRenderException` (or its
  /// `FluvieEncodeException` subtype) when the source or frame cannot be
  /// extracted.
  Future<RawFrame> extractFrame(
    Uri source,
    int frameIndex, {
    required int width,
    required int height,
  });
}
