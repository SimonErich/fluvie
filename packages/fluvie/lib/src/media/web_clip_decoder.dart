import 'dart:typed_data';

import 'package:fluvie/src/core/contracts/media_resolver.dart' show ClipMetadata;
import 'package:fluvie/src/rendering/capture/raw_frame.dart';

/// Decodes a video clip in the browser from its bytes — the WebCodecs seam the
/// web `MediaResolver` probes and extracts clip frames through.
///
/// The desktop path probes with ffprobe and extracts with ffmpeg by file path;
/// the browser has neither, so this works from the loaded bytes instead. The
/// `fluvie_web_encoder` package provides the real implementation over the
/// WebCodecs `VideoDecoder`; inject it (or a fake in tests) to render a `Clip`
/// on web. With no decoder wired, a clip declared on web fails with a clear
/// typed error instead of a blank frame.
abstract interface class WebClipDecoder {
  /// Probes [bytes] for the clip's fps, frame count, and pixel dimensions.
  Future<ClipMetadata> probe(Uint8List bytes);

  /// Decodes the [sourceFrames] of [bytes] to [width] by [height] RGBA rasters,
  /// each a [RawFrame] keyed by its source-frame index.
  Future<Map<int, RawFrame>> extractFrames(
    Uint8List bytes,
    List<int> sourceFrames, {
    required int width,
    required int height,
  });
}
