// fluvie:large-file-ok: the one capture entry point; a render is a long sequence of
// pre-passes and the whole value is that they live in one place, in order.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:fluvie/src/audio/encoding/audio_mix_staging.dart';
import 'package:fluvie/src/audio/runtime/spectral_beat_detection_service.dart';
import 'package:fluvie/src/audio/runtime/spectral_frequency_analyzer.dart';
import 'package:fluvie/src/composition/runtime/aspect_scope.dart';
import 'package:fluvie/src/composition/runtime/audio_collector.dart';
import 'package:fluvie/src/composition/runtime/caption_collector.dart';
import 'package:fluvie/src/composition/runtime/clip_plan_collector.dart'
    show ClipAudioPlan, collectClipAudioPlans;
import 'package:fluvie/src/composition/runtime/media_collector.dart';
import 'package:fluvie/src/composition/runtime/reactive_collector.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/aspect.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/contracts/beat_detection_service.dart';
import 'package:fluvie/src/core/contracts/clip_frame_preparer.dart';
import 'package:fluvie/src/core/contracts/frequency_analyzer.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/contracts/snapshot_service.dart';
import 'package:fluvie/src/core/export.dart';
import 'package:fluvie/src/core/quality.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/snapshot/runtime/snapshot_capture.dart';
import 'package:fluvie/src/elements/snapshot/runtime/snapshot_capture_scope.dart';
import 'package:fluvie/src/media/render_resolver_scope.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';
import 'package:fluvie/src/rendering/capture/capture_shell.dart';
import 'package:fluvie/src/rendering/capture/frame_capture_service.dart';
import 'package:fluvie/src/rendering/capture/raw_frame.dart';
import 'package:fluvie/src/rendering/capture/render_manifest.dart';
import 'package:fluvie/src/rendering/capture/repaint_boundary_capture_service.dart';
import 'package:fluvie/src/rendering/clip_audio_staging.dart';
import 'package:fluvie/src/rendering/encoding/frame_cache.dart';
import 'package:fluvie/src/rendering/no_media_resolver.dart';
import 'package:fluvie/src/rendering/pre_resolve_clips.dart';
import 'package:fluvie/src/rendering/render_aspect.dart' show ShellFramePump, ShellMount;
import 'package:fluvie/src/rendering/render_config.dart';
import 'package:fluvie/src/rendering/render_service.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

/// Runs [callback] on a real event loop, returning its result.
///
/// A `flutter_test` host passes `tester.runAsync` (real IO and `toImage` never
/// complete under fake async); a host with a real event loop passes
/// [runAsyncDirectly].
typedef ShellRunAsync = Future<T?> Function<T>(Future<T> Function() callback);

/// Points the host's view at the render canvas.
///
/// The snapshot pre-pass repoints the view while it rasterizes, so [renderVideo]
/// calls this again afterwards to restore the render size. A `flutter_test` host
/// sets `tester.view.physicalSize` / `devicePixelRatio`.
typedef SetViewSize = void Function(int width, int height);

/// The [ShellRunAsync] for a host that already has a real event loop: it simply
/// awaits [callback].
Future<T?> runAsyncDirectly<T>(Future<T> Function() callback) => callback();

/// The most pixels an untrusted render's canvas may span on either axis (8K).
/// A per-axis bound is checked FIRST and BEFORE any product, so a huge width or
/// height cannot overflow a 64-bit multiply to a small (or negative) value and
/// slip past — the whole reason width*height as the primary check is unsafe.
const int _maxUntrustedDimension = 7680;

/// The most frames an untrusted render may produce. With both axes bounded
/// above, this keeps the frame-bytes product far below the 64-bit ceiling.
const int _maxUntrustedFrames = 60 * 60 * 4;

/// The most raw-frame bytes an untrusted render may accumulate on disk
/// (width*height*4 per frame, summed over the frame count). Bounds a runaway
/// render's disk use independently of the wall-clock timeout.
const int _maxUntrustedFrameBytes = 10 * 1024 * 1024 * 1024;

/// Rejects an [untrusted] render whose final [width]x[height] canvas or total
/// frame size is out of bounds, before the frame loop allocates anything. A
/// trusted render (untrusted == false) is never bounded. Pure and directly
/// unit-testable; [_guardUntrustedRender] reads the untrusted flag from the
/// build define.
@visibleForTesting
void assertRenderWithinBounds({
  required bool untrusted,
  required int width,
  required int height,
  required int frameCount,
}) {
  if (!untrusted) return;
  // Per-axis, before any multiply: an overflowing width*height must not wrap to
  // a value under the limit. Both axes bounded, the products below are safe.
  if (width <= 0 ||
      height <= 0 ||
      width > _maxUntrustedDimension ||
      height > _maxUntrustedDimension) {
    throw StateError(
      'Untrusted render canvas ${width}x$height exceeds the '
      '${_maxUntrustedDimension}px per-axis limit.',
    );
  }
  if (frameCount < 0 || frameCount > _maxUntrustedFrames) {
    throw StateError(
      'Untrusted render of $frameCount frames exceeds the '
      '$_maxUntrustedFrames-frame limit.',
    );
  }
  if (width * height * 4 * frameCount > _maxUntrustedFrameBytes) {
    throw StateError(
      'Untrusted render of $frameCount ${width}x$height frames exceeds the '
      '$_maxUntrustedFrameBytes-byte limit.',
    );
  }
}

/// `FLUVIE_BLOCK_FILE_SOURCES` marks an untrusted render (a Playground snippet,
/// a posted spec, or an AI-authored spec); a trusted key/desktop render keeps
/// whatever size it declares, so the bound applies only under that define.
///
/// The define is compile-time-substituted into the library that names it, so
/// this read must stay inside fluvie's own `lib/` — the harness that drives a
/// render is generated text and cannot carry it.
void _guardUntrustedRender({required int width, required int height, required int frameCount}) =>
    assertRenderWithinBounds(
      untrusted: const bool.fromEnvironment('FLUVIE_BLOCK_FILE_SOURCES'),
      width: width,
      height: height,
      frameCount: frameCount,
    );

/// Counts real captures so a host can report cache hits.
class _CountingCaptureService implements FrameCaptureService {
  _CountingCaptureService(this._inner);

  final FrameCaptureService _inner;
  int captures = 0;

  @override
  Future<RawFrame> capture({
    required GlobalKey boundaryKey,
    required int frameIndex,
    required int width,
    required int height,
  }) {
    captures++;
    return _inner.capture(
      boundaryKey: boundaryKey,
      frameIndex: frameIndex,
      width: width,
      height: height,
    );
  }
}

/// Captures [video] into [outDir] (`frames.rgba` + `manifest.json`, manifest
/// written last) — the one capture path every Fluvie renderer drives.
///
/// This is the whole render, in order: resolve media (images, then clip frames),
/// rasterize any `Snapshot` subtree, parse captions, analyse reactive audio,
/// mount the production capture shell, then loop the frames. Everything a render
/// needs is derived from [video] itself, so the caller supplies no registry, no
/// media list, and no geometry.
///
/// The host owns only the mechanics it alone can provide: [pumpWidget] mounts a
/// tree, [pumpFrame] advances one frame, [setViewSize] points the view at the
/// canvas, and [runAsync] escapes fake async for real IO. A `flutter_test` host
/// passes `tester.pumpWidget`, `tester.pump`, its `view` setters, and
/// `tester.runAsync`; that is the only reason a capture runs under a test binding
/// at all.
///
/// Geometry: with [aspect] null the [video]'s own declared size wins; an explicit
/// [aspect] re-derives the canvas from `aspect.sizeFor(longEdge)` (the video's
/// longer side) and mounts an `AspectScope`, so every `Adaptive` branches for it.
/// `Aspect` has four families, so a size is never mapped back to one implicitly.
///
/// Media: with [resolver] null a real one is built through `resolverScope` (the
/// platform default — `rootBundle` plus the ffmpeg probe and frame extractor) and
/// disposed here, but **only when [video] actually declares media**, so a
/// media-less composition renders with no ffmpeg on `PATH`. Pass a [resolver] to
/// inject a fake; the caller then keeps ownership and it is never disposed.
///
/// Encoding is not part of this: the returned [RenderManifest] carries the
/// complete ffmpeg argument array for a caller to run.
Future<RenderManifest> renderVideo({
  required Video video,
  required Directory outDir,
  required ShellMount pumpWidget,
  required ShellFramePump pumpFrame,
  required SetViewSize setViewSize,
  ShellRunAsync runAsync = runAsyncDirectly,
  String compositionKey = 'render',
  int? frameCountOverride,
  bool cacheEnabled = false,
  Directory? cacheRoot,
  Aspect? aspect,
  Quality? quality,
  Export? export,
  Time? posterTime,
  MediaResolver? resolver,
  SnapshotService? snapshotService,
  BeatDetectionService? beatDetector,
  FrequencyAnalyzer? analyzer,
  String? defaultFontFamily,
  FrameCaptureService capture = const RepaintBoundaryCaptureService(),
  void Function(int completed, int total)? onProgress,
  void Function(int hits, int total)? onCacheReport,
}) async {
  // An aspect re-derives the canvas from aspect.sizeFor(longEdge), where longEdge
  // is the video's longer side; absent, the declared size wins (so a plain render
  // is byte-identical). Only layout branches per aspect.
  final size = aspect?.sizeFor(video.width > video.height ? video.width : video.height);
  final width = size?.width ?? video.width;
  final height = size?.height ?? video.height;
  final frameCount = frameCountOverride ?? video.totalFrames;
  // The one chokepoint every render passes with its FINAL, post-aspect canvas and
  // frame count. An untrusted render's size is runtime-derived, so this is the
  // only place a bound can be enforced for every path.
  _guardUntrustedRender(width: width, height: height, frameCount: frameCount);
  setViewSize(width, height);

  final config = RenderConfig(
    width: width,
    height: height,
    fps: video.fps,
    frameCount: frameCount,
    cacheEnabled: cacheEnabled,
    quality: quality ?? Quality.high,
  );
  // A poster Time resolves to an absolute frame against the render fps.
  final posterFrame = posterTime?.resolveFrames(
    TimeScopeData(fps: config.fps, startFrame: 0, durationFrames: config.frameCount),
  );

  final mediaSources = collectMediaSources(video.scenes);
  final snapshotSources = collectSnapshotSources(video.scenes);
  final captionSource = collectCaptionSource(video);
  final reactiveTracks = collectReactiveTracks(video);
  final declaresMedia =
      mediaSources.isNotEmpty ||
      snapshotSources.isNotEmpty ||
      captionSource != null ||
      reactiveTracks.allSources.isNotEmpty;

  // A media-less composition (text, shapes, charts, gradients) never builds a
  // resolver, so it renders with no ffmpeg and no bundle reads.
  final owned = resolver == null && declaresMedia ? resolverScope(null) : null;
  final active = resolver ?? owned?.resolver;

  SnapshotCaptureScope? snapshotScope;
  try {
    // Real IO — ffmpeg probes and extracts, the bundle reads, `toImage` reads back
    // — needs a real event loop, which fake async never pumps.
    await runAsync(() async {
      if (active == null) return null;
      // Images first: a clip source is content-hashed here before it is probed.
      await active.preResolveAll(mediaSources);
      await preResolveCompositionClips(
        composition: video,
        resolver: active,
        totalFrames: frameCount,
      );
      if (snapshotSources.isNotEmpty) {
        await active.preResolveSnapshots(
          snapshotSources,
          snapshotService ?? _missingSnapshotService(),
        );
      }
      if (captionSource != null) await active.preResolveCaptions(captionSource);
      if (reactiveTracks.allSources.isNotEmpty) {
        await active.preResolveReactive(
          reactiveTracks.allSources,
          beatDetector: beatDetector ?? SpectralBeatDetectionService(),
          analyzer: analyzer ?? SpectralFrequencyAnalyzer(),
          fps: config.fps,
          totalFrames: frameCount,
        );
      }
      // The in-process Snapshot subtree-capture pre-pass: rasterize every Snapshot
      // child once under the resolver (so an inner Image/Clip paints from the
      // decoded cache), then mount the result above the composition. Without it a
      // Snapshot in capture finds no scope and re-rasterizes every frame.
      snapshotScope = await _captureSnapshotScope(
        scenes: video.scenes,
        resolver: active,
        width: width,
        height: height,
        pumpWidget: pumpWidget,
        setViewSize: setViewSize,
      );
      return null;
    });
    // The pre-pass repointed the view while rasterizing; restore the render size.
    setViewSize(width, height);

    // `flutter test` renders text that names no family with the Ahem test font
    // (every glyph a filled box). A host that loaded real fonts names a family
    // here so unstyled text picks it up.
    Widget composition = video;
    if (aspect != null) composition = AspectScope(aspect: aspect, child: composition);
    // The capture shell mounts no app, so Text would throw
    // debugCheckHasDirectionality without this.
    composition = Directionality(textDirection: TextDirection.ltr, child: composition);
    if (defaultFontFamily != null) {
      composition = DefaultTextStyle.merge(
        style: TextStyle(fontFamily: defaultFontFamily),
        child: composition,
      );
    }

    final controller = RenderController();
    final boundaryKey = GlobalKey();
    final shell = buildCaptureShell(
      composition: composition,
      boundaryKey: boundaryKey,
      controller: controller,
      resolver: active,
      snapshotScope: snapshotScope,
      reactiveTracks: active == null ? noReactiveTracks : reactiveTracks,
    );

    final preparer = active != null && active is ClipFramePreparer
        ? active as ClipFramePreparer
        : null;
    // Warm the first frame's clip window before the tree mounts: the initial
    // pumpWidget builds at frame 0, before the capture loop's first decode-ahead,
    // so without this the first build's synchronous clip lookup would miss (that
    // build is not captured — the loop re-pumps frame 0 — but it would still throw).
    await runAsync(() async {
      await preparer?.prepareClipFrames(0);
      return null;
    });
    await pumpWidget(shell.tree);

    final counting = _CountingCaptureService(capture);
    // The resolver is what serves media during the loop AND what the audio mix
    // stages through, so the service is built here, after it exists — its `media`
    // is final at construction.
    final service = RenderService(
      capture: counting,
      cache: FrameCache(cacheRoot ?? FrameCache.defaultRoot()),
      media: active ?? const NoMediaResolver(),
    );
    final audio = _audioFor(video, resolver: active, fps: config.fps, totalFrames: frameCount);

    final mountedScope = shell.mountedSnapshotScope;
    late final RenderManifest manifest;
    await runAsync(() async {
      manifest = await service.captureToDirectory(
        config: config,
        outDir: outDir,
        pump: (frame) async {
          // Decode-ahead: a streaming resolver warms just the clip frames this
          // composition frame paints before the tree builds, so paint's
          // synchronous clip lookup is a hit without holding every frame in memory.
          await preparer?.prepareClipFrames(frame);
          controller.seek(frame);
          // Restart the Snapshot order cursor so the n-th unkeyed Snapshot reads
          // index n this frame, not n + (frame * count) — otherwise the indices
          // drift and a later frame throws on a missing raster.
          mountedScope?.resetCursor();
          await pumpFrame();
        },
        boundaryKey: boundaryKey,
        compositionKey: compositionKey,
        audioSources: audio.audioSources,
        stageAudio: audio.stageAudio,
        export: export,
        posterFrame: posterFrame,
        onProgress: onProgress,
        // Every source was pre-resolved above (images and clip frames alike); the
        // resolver is idempotent, so the service needs no re-pass — and re-passing
        // clip sources would try to decode a video as an image.
      );
      return null;
    });

    onCacheReport?.call(
      cacheEnabled ? config.frameCount - counting.captures : 0,
      config.frameCount,
    );
    return manifest;
  } finally {
    for (final image in snapshotScope?.images.values ?? const <ui.Image>[]) {
      image.dispose();
    }
    final release = owned?.dispose;
    if (release != null) await release();
  }
}

/// Rasterizes every `Snapshot` in [scenes] once and returns the scope holding the
/// stills, or `null` when there are none.
///
/// The wrapper (`RepaintBoundary` > `SizedBox` > `ImageResolverScope` >
/// `Directionality`) is built here so `SnapshotCaptureScope` never crosses the
/// public barrel; the host contributes only its pump and view seams.
Future<SnapshotCaptureScope?> _captureSnapshotScope({
  required List<Scene> scenes,
  required MediaResolver? resolver,
  required int width,
  required int height,
  required ShellMount pumpWidget,
  required SetViewSize setViewSize,
}) async {
  final snapshots = collectSnapshots(scenes);
  if (snapshots.isEmpty) return null;
  final keyed = <Key, Widget>{};
  final unkeyed = <Widget>[];
  for (final snapshot in snapshots) {
    final key = snapshot.key;
    if (key != null) {
      keyed[key] = snapshot.child;
    } else {
      unkeyed.add(snapshot.child);
    }
  }
  Future<void> pump(GlobalKey boundaryKey, Widget child) async {
    setViewSize(width, height);
    Widget boundary = RepaintBoundary(
      key: boundaryKey,
      child: SizedBox(width: width.toDouble(), height: height.toDouble(), child: child),
    );
    if (resolver != null) {
      boundary = ImageResolverScope(resolver: resolver, child: boundary);
    }
    await pumpWidget(Directionality(textDirection: TextDirection.ltr, child: boundary));
  }

  final images = await captureSnapshotChildren(pump: pump, keyed: keyed, unkeyed: unkeyed);
  return SnapshotCaptureScope(images: images);
}

/// The error a composition that declares `Mermaid`/`WebView`/`Html` gets when the
/// host wired no backend, naming the capability rather than failing at paint.
Never _missingSnapshotService() => throw StateError(
  'This composition declares a Snapshot element (Mermaid, WebView, or Html), '
  'which needs a SnapshotService to rasterize it before the frame loop. Pass '
  'renderVideo(snapshotService: ...) with a backend.',
);

/// Resolves the encoder audio mix for [video]: its declared `Audio` tracks plus
/// any clip's embedded audio, or `(null, [])` for a silent composition (so the
/// encoder's `-an` path stands).
({AudioMixStager? stageAudio, Iterable<AudioSource> audioSources}) _audioFor(
  Video video, {
  required MediaResolver? resolver,
  required int fps,
  required int totalFrames,
}) {
  final tracks = collectAudioTracks(video);
  // Only clips that actually carry an audio track join the mix (each was probed
  // above); a silent clip would otherwise fail the encoder's `[N:a]` map.
  final clipPlans = resolver == null
      ? const <ClipAudioPlan>[]
      : collectClipAudioPlans(
          video.scenes,
          fps,
        ).where((plan) => resolver.clipMetadataFor(plan.source).hasAudio).toList();
  if (tracks.isEmpty && clipPlans.isEmpty) {
    return (stageAudio: null, audioSources: const []);
  }
  return (
    stageAudio: ({required resolver, required sandbox}) async {
      // A clip's embedded audio is staged from the clip's video file and joins
      // the same amix as the declared tracks.
      final clipNodes = await stageClipAudio(
        plans: clipPlans,
        resolver: resolver,
        sandbox: sandbox,
        fps: fps,
        totalFrames: totalFrames,
      );
      final plan = await stageAudioMix(
        tracks: tracks,
        resolver: resolver,
        sandbox: sandbox,
        fps: fps,
        totalFrames: totalFrames,
        extraNodes: clipNodes,
      );
      return (nodes: plan.tracks, amix: plan.amix);
    },
    audioSources: {
      ...collectAudioSources(video),
      for (final plan in clipPlans) clipAudioSourceFor(plan.source),
    },
  );
}
