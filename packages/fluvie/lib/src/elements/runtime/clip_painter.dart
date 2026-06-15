import 'package:flutter/widgets.dart' show BoxFit, BuildContext, StatelessWidget, Widget;
import 'package:flutter/widgets.dart' as flutter;
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/elements/runtime/clip_resampler.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

/// Paints one pre-extracted clip frame: in capture it resamples the composition
/// frame to a source frame and hands the cached `ui.Image` to a synchronous
/// `RawImage`.
///
/// The composition frame comes from [FrameProvider]; the enclosing
/// [TimeScopeProvider] gives the window start and the composition fps. The
/// resolver's [ClipMetadata] gives the source fps and frame count, and [trim]
/// (resolved in *source* frame space) gives the clamp bounds the resampler
/// reads. A capture with no resolver in scope is a determinism violation and
/// throws a [FluvieRenderException] naming the source and the collect pass.
/// In a live preview (no scope) it paints a placeholder, since determinism does
/// not bind there.
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
      return const flutter.SizedBox.expand();
    }
    final sourceFrame = _resolveSourceFrame(context, resolver);
    return flutter.RawImage(image: resolver.decodedClipFrame(source, sourceFrame), fit: fit);
  }

  /// Maps the current composition frame to a source frame via [resampleClipFrame].
  int _resolveSourceFrame(BuildContext context, MediaResolver resolver) {
    final compFrame = FrameProvider.of(context).frame;
    final scope = TimeScopeProvider.of(context);
    final meta = resolver.clipMetadataFor(source);
    final bounds = _trimBounds(meta);
    return resampleClipFrame(
      compFrame: compFrame,
      windowStart: scope.startFrame,
      compFps: scope.fps,
      srcFps: meta.fps,
      trimStartFrames: bounds.start,
      trimEndFrames: bounds.end,
    );
  }

  /// Resolves [trim] into source frame bounds, defaulting to the whole source.
  ({int start, int end}) _trimBounds(ClipMetadata meta) {
    if (trim == null) return (start: 0, end: meta.frameCount);
    final sourceScope = TimeScopeData(
      fps: meta.fps.round(),
      startFrame: 0,
      durationFrames: meta.frameCount,
    );
    return trim!.resolveClamped(sourceScope, min: 0, max: meta.frameCount);
  }
}
