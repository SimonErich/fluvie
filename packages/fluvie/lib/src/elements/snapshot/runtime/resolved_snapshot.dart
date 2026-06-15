import 'package:flutter/widgets.dart';
import 'package:flutter/widgets.dart' as flutter;
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/media/snapshot_source.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';

/// Paints one pre-resolved [SnapshotSource]: the single synchronous `RawImage`
/// paint path `Mermaid`, `WebView`, and `Html` share — a snapshot is just
/// another resolved media.
///
/// When an [ImageResolverScope] is above the build context the snapshot is
/// already rasterized and decoded, so paint hands the cached `ui.Image` straight
/// to a Flutter `RawImage` (no live platform view, no async pop-in). With no
/// scope the behaviour splits on the render mode, mirroring `ResolvedImage`: a
/// capture without pre-resolution is a determinism violation and throws a
/// [FluvieRenderException] naming the source and the collect pass
/// (`collectSnapshotSources`); a live preview falls back to a documented sized
/// placeholder, because capturing a live platform view in the frame loop is
/// exactly what the pre-rasterize rule forbids.
///
/// An [opacity] below `1.0` modulates the raster's alpha through the `RawImage`
/// color/blend channel (a `BlendMode.modulate` color filter), so the staged
/// `Mermaid` reveal fades the diagram without a `saveLayer` — capture-safe.
final class ResolvedSnapshot extends StatelessWidget {
  /// Paints [source] scaled by [fit] (default contain) at [opacity] (default
  /// fully opaque).
  const ResolvedSnapshot({
    required this.source,
    this.fit = BoxFit.contain,
    this.opacity = 1.0,
    super.key,
  });

  /// The declared snapshot to paint, pre-resolved before the frame loop in
  /// capture.
  final SnapshotSource source;

  /// How the raster scales into its box; defaults to [BoxFit.contain] so a
  /// diagram or page is never cropped.
  final BoxFit fit;

  /// The paint opacity (`0..1`); below `1.0` the raster's alpha is modulated.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final resolver = ImageResolverScope.maybeOf(context);
    if (resolver != null) {
      final image = resolver.decodedSnapshotFor(source);
      return opacity >= 1.0
          ? flutter.RawImage(image: image, fit: fit)
          : flutter.RawImage(
              image: image,
              fit: fit,
              color: Color.fromRGBO(255, 255, 255, opacity.clamp(0.0, 1.0)),
              colorBlendMode: BlendMode.modulate,
            );
    }
    if (RenderModeContext.isCapture(context)) {
      throw FluvieRenderException(
        'Snapshot "$source" cannot render in capture without a pre-resolved '
        'raster. Mount an ImageResolverScope and include the source in the '
        'collect pass (collectSnapshotSources) before the frame loop.',
      );
    }
    return _previewPlaceholder();
  }

  /// The documented preview placeholder used only in a live preview: a sized
  /// box, never a live platform view (the pre-rasterize rule forbids capturing
  /// one in the frame loop).
  Widget _previewPlaceholder() => const SizedBox.expand();
}
