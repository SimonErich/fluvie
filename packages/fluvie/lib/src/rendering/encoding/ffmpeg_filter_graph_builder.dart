import 'package:fluvie/src/rendering/encoding/ffmpeg_filter_graph.dart';

/// Composes the output [FfmpegFilterGraph] for an encode.
///
/// Emits exactly one node — `format=pix_fmts=yuv420p` — because the
/// raw RGBA frames are captured at the target resolution already; a `scale`
/// node joins the chain only for sources whose size can differ from the
/// output.
///
/// Takes the output dimensions as primitives rather than a `RenderConfig`:
/// the config type layers on top of this builder, keeping `encoding/` free of
/// upward dependencies.
final class FfmpegFilterGraphBuilder {
  /// Creates a stateless builder; every call plans from scratch.
  const FfmpegFilterGraphBuilder();

  /// The filter chain for frames of [width]x[height] pixels.
  ///
  /// Both dimensions must be even — yuv420p chroma subsampling halves them,
  /// so odd sizes cannot encode. Throws [ArgumentError] otherwise.
  FfmpegFilterGraph forFrames({required int width, required int height}) {
    if (width.isOdd || width <= 0) {
      throw ArgumentError.value(width, 'width', 'must be positive and even for yuv420p output');
    }
    if (height.isOdd || height <= 0) {
      throw ArgumentError.value(height, 'height', 'must be positive and even for yuv420p output');
    }
    return FfmpegFilterGraph()..add(FilterNode('format', args: const {'pix_fmts': 'yuv420p'}));
  }
}
