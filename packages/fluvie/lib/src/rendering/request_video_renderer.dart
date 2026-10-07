import 'package:fluvie/src/rendering/video_render_request.dart';
import 'package:fluvie_media/fluvie_media.dart' show RenderCapabilities;

/// Optional complete-request seam for built-in and custom render adapters.
///
/// Existing `VideoRenderer` implementations remain supported. Implement this
/// alongside that legacy interface to receive exact geometry, capture range,
/// authored export choices, poster selection, audio policy and cancellation.
abstract interface class RequestVideoRenderer<T> {
  /// Choices this adapter can validate before capturing output pixels.
  RenderCapabilities get capabilities;

  /// Renders the complete [request], rejecting unsupported choices explicitly.
  Future<T> renderRequest(VideoRenderRequest request);
}
