import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/media/net/network_allowlist.dart';
import 'package:fluvie/src/media/render_resolver_scope.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';
import 'package:fluvie/src/media/web_clip_decoder.dart';
import 'package:fluvie/src/rendering/collect_composition_media.dart';
import 'package:fluvie/src/rendering/pre_resolve_clips.dart';

/// Gives a live preview the media half of the capture shell: it runs the same
/// pre-resolve pass a render runs, then mounts the same [ImageResolverScope]
/// above [composition] — so `Clip`, `Background.video`, and `Image` paint
/// through the *capture* painters rather than a second, divergent decode path.
///
/// Preview already shares the clock (`RenderControllerScope` → `FrameProvider`)
/// and scene timing with capture, so the resolver is the only missing input: a
/// `Clip` with no resolver above it has nothing to paint and falls back to its
/// placeholder. Mount this inside a `LivePlayer` (which owns the ticker and the
/// render mode) to reproduce capture's depth order:
///
/// ```dart
/// LivePlayer(
///   controller: playback,
///   child: PreviewMediaScope(composition: video),
/// )
/// ```
///
/// Warm-up is asynchronous and runs once per composition, so the placeholder
/// shows until the frames are decoded. It is not instant: the desktop path
/// spawns one ffmpeg per extracted frame, so a few seconds of clip takes a few
/// seconds to warm. **A failure is never fatal**: no ffmpeg on `PATH`, no
/// WebCodecs decoder wired, or an unreadable source leaves the scope unmounted
/// and the preview falls back to exactly the placeholder it shows today
/// (reported through `FlutterError` in debug, so the cause is never silent).
///
/// Decoded frames are held in memory for the whole preview, so [maxClipEdge]
/// bounds a clip's decode to a proxy resolution (a full-HD frame costs ~8.3 MB;
/// a few seconds of one would otherwise cost hundreds). It moves pixels only:
/// timing, `trim`, and resampling read the source's own probed facts, and a
/// proxy raster still *lays out* at the source's size (to within the decode's
/// even-pixel rounding), so a clip under a loose constraint fills the same box
/// it fills in the render. Pass `null` to decode at full source resolution.
final class PreviewMediaScope extends StatefulWidget {
  /// Pre-resolves [composition]'s media, then mounts it under a resolver.
  const PreviewMediaScope({
    required this.composition,
    this.resolver,
    this.clipDecoder,
    this.networkAllowlist,
    this.maxClipEdge = 720,
    super.key,
  }) : assert(
         maxClipEdge == null || maxClipEdge > 0,
         'maxClipEdge must be a positive pixel length; pass null for no bound',
       );

  /// The composition to pre-resolve and display — the `Video` (or a widget
  /// wrapping one). It is this scope's child as well as its collect target.
  final Widget composition;

  /// A resolver to use as-is instead of building one from the platform provider
  /// (a fake in tests). The caller keeps ownership: it is never disposed here.
  ///
  /// Its type lives on the pipeline surface (`package:fluvie/rendering.dart`);
  /// an authoring preview leaves this null and gets the platform's own resolver.
  final MediaResolver? resolver;

  /// The in-browser clip decoder (WebCodecs) — required for a `Clip` to decode
  /// on web, ignored elsewhere. `fluvie_web_encoder` provides one; the type
  /// comes from `package:fluvie/rendering.dart`. Desktop needs none (it decodes
  /// through ffmpeg).
  final WebClipDecoder? clipDecoder;

  /// The safety gate for network media, from `package:fluvie/rendering.dart`;
  /// defaults to the provider's allowlist.
  final NetworkAllowlist? networkAllowlist;

  /// The longest side a clip decodes at in preview, or `null` for the source's
  /// own resolution. Bounds memory; does not affect timing.
  final int? maxClipEdge;

  @override
  State<PreviewMediaScope> createState() => _PreviewMediaScopeState();
}

class _PreviewMediaScopeState extends State<PreviewMediaScope> {
  MediaResolver? _resolver;
  Future<void> Function()? _release;

  @override
  void initState() {
    super.initState();
    // Nothing awaits the warm-up: it publishes the resolver through setState
    // when it lands, and the placeholder covers the tree until then.
    unawaited(_warmUp());
  }

  @override
  void didUpdateWidget(PreviewMediaScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The warm-up is keyed to the composition's media; a new composition needs a
    // fresh pass. Identical compositions (a rebuild) keep the warm resolver.
    if (identical(oldWidget.composition, widget.composition)) return;
    _teardown();
    setState(() => _resolver = null);
    unawaited(_warmUp());
  }

  @override
  void dispose() {
    _teardown();
    super.dispose();
  }

  /// Releases an owned resolver and forgets it, so a rebuild or unmount never
  /// leaves decoded frames or a provider container alive.
  void _teardown() {
    final release = _release;
    _release = null;
    _resolver = null;
    // `dispose` is synchronous and there is nothing left to report a failed
    // release to, so the teardown runs unawaited.
    if (release != null) unawaited(release());
  }

  /// Runs the render's own pre-pass — images first (a clip is content-hashed
  /// there), then the clip probe and frame extraction — and publishes the
  /// resolver only once every frame paint will read is decoded and warm.
  ///
  /// A failure is never fatal: a preview that cannot decode its media still
  /// shows the composition, with each media element on its own fallback. It is
  /// reported (debug builds, non-fatal) rather than swallowed, because the
  /// symptom otherwise is a placeholder with no stated cause.
  Future<void> _warmUp() async {
    final composition = widget.composition;
    final video = compositionVideo(composition);
    if (video == null) return;
    final scope = resolverScope(
      widget.resolver,
      networkAllowlist: widget.networkAllowlist,
      clipDecoder: widget.clipDecoder,
      clipDecodeMaxEdge: widget.maxClipEdge,
      // A render streams clip frames and decodes each window from its capture
      // loop; a preview's clock is a Ticker, which cannot await a decode, so
      // nothing here can drive that window. Decode every planned frame up front
      // instead — which is what makes the proxy bound above load-bearing.
      streamClipFrames: false,
    );
    try {
      await scope.resolver.preResolveAll(collectCompositionMedia(composition));
      await preResolveCompositionClips(
        composition: composition,
        resolver: scope.resolver,
        totalFrames: video.totalFrames,
      );
    } on Object catch (error, stack) {
      await scope.dispose();
      _reportWarmUpFailure(error, stack);
      return;
    }
    // The tree may have gone away (or moved on to another composition) while the
    // decode ran; the resolver we just warmed is then ours to release.
    if (!mounted || !identical(widget.composition, composition)) {
      await scope.dispose();
      return;
    }
    // Release whatever is already published before taking its place: two
    // warm-ups can be in flight at once (the composition swapped away and back),
    // and overwriting _release would strand the earlier resolver's frames.
    _teardown();
    setState(() {
      _resolver = scope.resolver;
      _release = scope.dispose;
    });
  }

  /// Reports a failed warm-up in debug builds without breaking the preview: the
  /// media falls back, but the author is told why rather than left staring at a
  /// placeholder. Release builds stay silent — a shipped app is not authoring.
  void _reportWarmUpFailure(Object error, StackTrace stack) {
    if (!kDebugMode) return;
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'fluvie',
        context: ErrorDescription(
          'pre-resolving media for a live preview. The composition still shows, '
          'but its clips paint their placeholder instead of real frames. A clip '
          'decodes through ffmpeg on desktop (it must be on PATH) or through '
          "fluvie_web_encoder's decoder passed to PreviewMediaScope(clipDecoder:) "
          'on web',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolver = _resolver;
    if (resolver == null) return widget.composition;
    return ImageResolverScope(resolver: resolver, child: widget.composition);
  }
}
