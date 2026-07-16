import 'package:fluvie/src/rendering/capture/raw_frame.dart';

/// Extracts one decoded frame of a video source as a [RawFrame].
///
/// This is the contract the `Clip` render path consumes: during capture, a
/// clip's pixels for frame *n* come from here instead of from a live player.
/// Tests run against a canned fake; the ffmpeg-backed service supplies the
/// pixels at render.
abstract interface class FrameExtractionService {
  /// The decoded pixels of [source] at [frameIndex] (in the source's own
  /// frame space), scaled to exactly [width] x [height].
  ///
  /// The caller pins the output size (from a prior probe) so the returned
  /// [RawFrame] always holds `width * height * 4` bytes — deterministic and
  /// directly compositable. Pass [decoder] to name the decoder the source needs
  /// (`libvpx-vp9` for VP9 with alpha); leave it null to let the backend pick.
  /// Throws a `FluvieRenderException` (or its `FluvieEncodeException` subtype)
  /// when the source or frame cannot be extracted.
  Future<RawFrame> extractFrame(
    Uri source,
    int frameIndex, {
    required int width,
    required int height,
    String? decoder,
  });

  /// The decoded pixels of [source] at each index in [frameIndices], keyed by
  /// index and scaled to [width] x [height] — the batch the clip pre-pass uses.
  ///
  /// The ffmpeg service extracts each via [extractFrame]; a platform decoder
  /// (WebCodecs, `MediaCodec`, AVFoundation) overrides this with a single
  /// forward-decode pass, because seeking to a keyframe per frame is far slower.
  /// [decoder] carries the same meaning as on [extractFrame]; a backend that
  /// does not choose its decoder by name ignores it.
  Future<Map<int, RawFrame>> extractFrames(
    Uri source,
    Iterable<int> frameIndices, {
    required int width,
    required int height,
    String? decoder,
  });
}
