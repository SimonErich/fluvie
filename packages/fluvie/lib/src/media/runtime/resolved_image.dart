import 'package:flutter/widgets.dart';
import 'package:flutter/widgets.dart' as flutter;
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/media/runtime/file_image.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';

/// Paints one pre-resolved [MediaSource]: a synchronous
/// `RawImage` in capture, Flutter's async image path in preview.
///
/// When an [ImageResolverScope] is above the build context the source is
/// already decoded, so paint hands the cached `ui.Image` straight to a Flutter
/// `RawImage` (no `ImageProvider`, no async pop-in). With no scope the
/// behaviour splits on the render mode: a capture without pre-resolution is a
/// determinism violation and throws a [FluvieRenderException] naming the source
/// and the collect pass; a live preview falls back to Flutter's
/// async image, where determinism does not bind.
///
/// The asset/network/file/memory branches of the preview fallback mirror the
/// four [MediaSource] variants one-to-one.
final class ResolvedImage extends StatelessWidget {
  /// Paints [source] scaled by [fit] (default cover).
  const ResolvedImage({required this.source, this.fit, super.key});

  /// The declared media to paint, pre-resolved before the frame loop in capture.
  final MediaSource source;

  /// How the image scales into its box; `null` lets Flutter pick its default.
  final BoxFit? fit;

  @override
  Widget build(BuildContext context) {
    final resolver = ImageResolverScope.maybeOf(context);
    if (resolver != null) {
      return flutter.RawImage(image: resolver.decodedImageFor(source), fit: fit);
    }
    if (RenderModeContext.isCapture(context)) {
      throw FluvieRenderException(
        'Image "$source" cannot render in capture without a pre-resolved '
        'source. Mount an ImageResolverScope and include the source in the '
        'collect pass (collectMediaSources) before the frame loop.',
      );
    }
    return _previewFallback();
  }

  /// Flutter's async image path used only in a live preview.
  Widget _previewFallback() => switch (source) {
    AssetSource(:final name) => flutter.Image.asset(name, fit: fit),
    NetworkSource(:final url) => flutter.Image.network(url.toString(), fit: fit),
    // coverage:ignore-start: live-preview-only file and memory arms; they read the real
    // filesystem or decode bytes, which the capture path never touches.
    FileSource(:final path) => fileImagePreview(path, fit),
    MemorySource(:final bytes) => flutter.Image.memory(bytes, fit: fit),
    // coverage:ignore-end
  };
}
