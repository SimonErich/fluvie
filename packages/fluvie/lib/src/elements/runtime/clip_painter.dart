import 'package:flutter/widgets.dart' as flutter;
import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/keyframed_number.dart';
import 'package:fluvie/src/core/contracts/clip_timeline_resolver.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/elements/runtime/clip_frame_planner.dart';
import 'package:fluvie/src/elements/runtime/clip_resampler.dart';
import 'package:fluvie/src/elements/runtime/clip_speed_profile.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';
import 'package:fluvie/src/media/runtime/preview_clip_scope.dart';
import 'package:fluvie/src/media/runtime/resolved_image.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/rendering/runtime/preparation_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

part 'clip_preview_placeholder.dart';

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
  /// [trim] in source space and retimed by [speed]. [poster] stands in for
  /// unresolved preview frames.
  const ClipPainter({
    required this.source,
    this.trim,
    this.fit,
    this.poster,
    this.speed = 1,
    this.speedRamp,
    super.key,
  });

  /// The declared clip media, pre-extracted before the frame loop in capture.
  final MediaSource source;

  /// The portion of the source video to play (source-time), or `null` for all
  /// of it.
  final TimeRange? trim;

  /// How the frame scales into its box; `null` lets Flutter pick its default.
  final BoxFit? fit;

  /// The still to show while preview frames are unresolved, or `null` for
  /// the labelled placeholder.
  final MediaSource? poster;

  /// The playback rate handed to the resampler; `1` is source speed and a
  /// negative rate plays the trim backwards.
  final double speed;

  /// Positive time-varying playback rate, integrated on the output clock.
  final KeyframedNumber? speedRamp;

  @override
  Widget build(BuildContext context) {
    if (PreparationScope.exposesOnlyGeometry(context)) {
      final prepared = PreparationScope.resolverOf(context);
      if (prepared != null) {
        try {
          final meta = prepared.clipMetadataFor(source);
          return SizedBox(width: meta.width.toDouble(), height: meta.height.toDouble());
        } on Object {
          /* The first pass collects before metadata exists. */
        }
      }
      return const SizedBox.shrink();
    }

    PreparationScope.requirePrepared(context, source, 'clip');
    final resolver = ImageResolverScope.maybeOf(context);
    if (resolver == null) {
      if (RenderModeContext.isCapture(context)) {
        throw FluvieRenderException(
          'Clip "$source" cannot render in capture without a pre-resolved '
          'source. Mount an ImageResolverScope and include the source in the '
          'collect pass (collectMediaSources) before the frame loop.',
        );
      }
      final still = poster;
      if (still != null) return ResolvedImage(source: still, fit: fit);
      return _ClipPreviewPlaceholder(source: source);
    }
    final meta = resolver.clipMetadataFor(source);
    final clock = FrameProvider.of(context).frame;
    final window = TimeScopeProvider.of(context);
    if (clock < window.startFrame || clock >= window.startFrame + window.durationFrames) {
      return SizedBox(width: meta.width.toDouble(), height: meta.height.toDouble());
    }
    final requested = _resolveSourceFrame(context, meta);
    final frame = RenderModeContext.isCapture(context)
        ? requested
        : PreviewClipScope.frameFor(context, source, requested);
    final image = resolver.decodedClipFrame(source, frame);
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
    final resolver = ImageResolverScope.of(context);
    final timeline = clipTimelineFor(resolver, source);
    final bounds = resolveClipTrimBounds(trim, meta, timeline: timeline);
    final offsets = resolveClipTrimOffsets(trim, meta, timeline: timeline);
    return resampleClipFrame(
      compFrame: compFrame,
      windowStart: scope.startFrame,
      compFps: scope.fps,
      srcFps: meta.fps,
      timeline: timeline,
      trimStartFrames: bounds.start,
      trimEndFrames: bounds.end,
      trimStartOffsetFrames: offsets.start - bounds.start,
      trimEndOffsetFrames: offsets.end - bounds.end,
      speed: speed,
      sourceTimeMap: speedRamp == null
          ? null
          : integrateClipSpeedRamp(speedRamp!, fps: scope.fps, windowFrames: scope.durationFrames),
    );
  }
}
