import 'package:flutter/widgets.dart';
import 'package:flutter/widgets.dart' as flutter;
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/elements/runtime/clip_frame_planner.dart';
import 'package:fluvie/src/elements/runtime/clip_resampler.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

/// Paints one pre-extracted clip frame: in capture it resamples the composition
/// frame to a source frame and hands the cached `ui.Image` to a synchronous
/// `RawImage`.
///
/// The composition frame comes from [FrameProvider]; the enclosing
/// [TimeScopeProvider] gives the window start and the composition fps. The
/// resolver's [ClipMetadata] gives the source fps, frame count, and *source*
/// dimensions, and [trim] (resolved in source frame space) gives the clamp
/// bounds the resampler reads. A capture with no resolver in scope is a
/// determinism violation and throws a [FluvieRenderException] naming the source
/// and the collect pass. In a live preview (no scope) it paints a labelled
/// placeholder, since determinism does not bind there.
///
/// The painted frame reports the *source's* size, not the decoded raster's: a
/// live preview may decode at a proxy resolution, and `RawImage`'s intrinsic
/// size is `image.width / scale`, so the scale below cancels the proxy out.
/// Without it a clip under a loose constraint would lay out smaller in preview
/// than it renders. In capture the raster is the source size and the scale is
/// 1.0, so nothing changes there.
final class ClipPainter extends StatelessWidget {
  /// Paints [source] resampled per the current frame, scaled by [fit], honoring
  /// [trim] in source space.
  const ClipPainter({required this.source, this.trim, this.fit, super.key});

  /// The declared clip media, pre-extracted before the frame loop in capture.
  final MediaSource source;

  /// The portion of the source video to play (source-time), or `null` for all
  /// of it.
  final TimeRange? trim;

  /// How the frame scales into its box; `null` lets Flutter pick its default.
  final BoxFit? fit;

  @override
  Widget build(BuildContext context) {
    final resolver = ImageResolverScope.maybeOf(context);
    if (resolver == null) {
      if (RenderModeContext.isCapture(context)) {
        throw FluvieRenderException(
          'Clip "$source" cannot render in capture without a pre-resolved '
          'source. Mount an ImageResolverScope and include the source in the '
          'collect pass (collectMediaSources) before the frame loop.',
        );
      }
      return _ClipPreviewPlaceholder(source: source);
    }
    final meta = resolver.clipMetadataFor(source);
    final image = resolver.decodedClipFrame(source, _resolveSourceFrame(context, meta));
    return flutter.RawImage(image: image, fit: fit, scale: _rasterScale(image.width, meta.width));
  }

  /// The `RawImage` scale that makes a raster decoded at [rasterWidth] report the
  /// source's [sourceWidth] as its intrinsic width (`image.width / scale`).
  ///
  /// A proxy-decoded preview raster gives a scale below 1.0; a full-resolution
  /// capture raster gives exactly 1.0. Falls back to 1.0 for a degenerate source
  /// width rather than dividing by zero.
  double _rasterScale(int rasterWidth, int sourceWidth) =>
      sourceWidth <= 0 ? 1.0 : rasterWidth / sourceWidth;

  /// Maps the current composition frame to a source frame via [resampleClipFrame].
  int _resolveSourceFrame(BuildContext context, ClipMetadata meta) {
    final compFrame = FrameProvider.of(context).frame;
    final scope = TimeScopeProvider.of(context);
    final bounds = resolveClipTrimBounds(trim, meta);
    return resampleClipFrame(
      compFrame: compFrame,
      windowStart: scope.startFrame,
      compFps: scope.fps,
      srcFps: meta.fps,
      trimStartFrames: bounds.start,
      trimEndFrames: bounds.end,
    );
  }
}

/// The live-preview stand-in for a [ClipPainter]: real frames exist only after
/// the pre-resolve pass, so a preview shows a faint, labelled box that marks
/// where the clip sits and how big its box is — what an author needs to
/// position it.
///
/// It fills the box the layout gives it, but — like Flutter's own
/// `RawImage`/`Image` when they have no intrinsic size — never demands infinite
/// size: the [LimitedBox] collapses it to zero on any axis the parent left
/// unbounded (which [ClipPainter]'s debug warning then explains) rather than
/// asserting. A self-contained [Directionality] lets the label render without
/// depending on an ambient text direction.
class _ClipPreviewPlaceholder extends StatelessWidget {
  const _ClipPreviewPlaceholder({required this.source});

  /// The clip being stood in for, used only to label the placeholder.
  final MediaSource source;

  @override
  Widget build(BuildContext context) {
    return LimitedBox(
      maxWidth: 0,
      maxHeight: 0,
      child: SizedBox.expand(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0x14FFFFFF),
            border: Border.all(color: const Color(0x66FFFFFF), width: 2),
            borderRadius: const BorderRadius.all(Radius.circular(8)),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  '▶  ${_label(source)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(color: Color(0x99000000), blurRadius: 4)],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A short human label for [source] — the file/asset basename, the URL's last
  /// segment, or a memory clip's debug label.
  String _label(MediaSource source) => switch (source) {
    AssetSource(:final name) => name.split('/').last,
    FileSource(:final path) => path.split(RegExp(r'[\\/]')).last,
    NetworkSource(:final url) => url.pathSegments.isNotEmpty ? url.pathSegments.last : url.host,
    MemorySource(:final debugLabel) => debugLabel ?? 'clip',
  };
}
