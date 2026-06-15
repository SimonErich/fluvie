import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/rendering/capture/frame_capture_service.dart';
import 'package:fluvie/src/rendering/capture/raw_frame.dart';

/// The real [FrameCaptureService]: rasterizes the [RepaintBoundary] under the
/// given key via `toImage(pixelRatio: 1.0)` and reads back raw RGBA bytes.
///
/// The pixel chain is fixed end-to-end: the host sets the
/// view's physical size to the target resolution at device pixel ratio 1.0,
/// so `pixelRatio: 1.0` here yields exactly `width`x`height` pixels — any
/// other size is a configuration error and throws a [FluvieRenderException]
/// naming both sizes.
///
/// In widget tests, `toImage`/`toByteData` complete on real engine callbacks
/// that fake-async never drives — run every [capture] call inside
/// `tester.runAsync` (see `test/rendering/capture/to_image_spike_test.dart`
/// for the mechanics).
final class RepaintBoundaryCaptureService implements FrameCaptureService {
  /// Creates the capture service. Stateless and const: all state lives in the
  /// tree under the boundary key.
  const RepaintBoundaryCaptureService();

  /// Captures the boundary's pixels for [frameIndex]; the `toImage()` call
  /// relies on the implicit `pixelRatio` default of 1.0, which is load-bearing
  /// for the exact-dimension contract pinned by the spike and service tests
  /// (the fatal `avoid_redundant_argument_values` lint forbids spelling it).
  @override
  Future<RawFrame> capture({
    required GlobalKey boundaryKey,
    required int frameIndex,
    required int width,
    required int height,
  }) async {
    final boundary = _findBoundary(boundaryKey);
    final image = await boundary.toImage();
    try {
      if (image.width != width || image.height != height) {
        throw FluvieRenderException(
          'Capture size mismatch: expected ${width}x$height but the boundary '
          'painted ${image.width}x${image.height}. Set the view physical size '
          'to the target resolution with devicePixelRatio 1.0 before pumping.',
        );
      }
      // rawRgba is toByteData's default format; relied on
      // here, and asserted byte-for-byte by the spike + acceptance tests.
      final data = await image.toByteData();
      if (data == null) {
        // Reason: defensive engine-failure guard. toByteData returns data for a
        // valid RepaintBoundary, so this never fires in tests.
        // coverage:ignore-start
        throw FluvieRenderException(
          'The engine returned no byte data for frame $frameIndex '
          '(${width}x$height rawRgba read-back failed).',
        );
        // coverage:ignore-end
      }
      final rgba = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      return RawFrame(frameIndex: frameIndex, width: width, height: height, rgba: rgba);
    } finally {
      image.dispose();
    }
  }

  static RenderRepaintBoundary _findBoundary(GlobalKey boundaryKey) {
    final context = boundaryKey.currentContext;
    if (context == null) {
      throw FluvieRenderException(
        'The capture boundary key is not mounted: no RepaintBoundary with this '
        'key is in the tree. Wrap the composition in RepaintBoundary(key: ...) '
        'and pump it before capturing.',
      );
    }
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw FluvieRenderException(
        'The capture key must sit on a RepaintBoundary (RenderRepaintBoundary), '
        'but its render object is ${renderObject.runtimeType}. Move the key to '
        'the RepaintBoundary that wraps the composition.',
      );
    }
    return renderObject;
  }
}
