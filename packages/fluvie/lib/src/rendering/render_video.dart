import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/aspect.dart';
import 'package:fluvie/src/core/contracts/beat_detection_service.dart';
import 'package:fluvie/src/core/contracts/frequency_analyzer.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/contracts/snapshot_service.dart';
import 'package:fluvie/src/core/export.dart';
import 'package:fluvie/src/core/quality.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/media/render_resolver_scope.dart';
import 'package:fluvie/src/rendering/capture/frame_capture_service.dart';
import 'package:fluvie/src/rendering/capture/raw_frame.dart';
import 'package:fluvie/src/rendering/capture/render_manifest.dart';
import 'package:fluvie/src/rendering/capture/repaint_boundary_capture_service.dart';
import 'package:fluvie/src/rendering/encoding/frame_cache.dart';
import 'package:fluvie/src/rendering/render_aspect.dart' as capture_aspect;
import 'package:fluvie/src/rendering/render_bounds.dart';
import 'package:fluvie/src/rendering/render_cancellation.dart';
import 'package:fluvie/src/rendering/render_host_callbacks.dart';
import 'package:fluvie/src/rendering/render_service.dart';
import 'package:fluvie/src/rendering/video_render_request.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

export 'render_bounds.dart';
export 'render_host_callbacks.dart';

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

/// Captures a Video through the shared mounted composition pipeline.
///
/// Its authored canvas and timing stay intact unless [aspect] selects an
/// adaptive layout. [frameCountOverride] captures a prefix; it does not shorten
/// relative animations, audio envelopes or poster timing. [frameStart] seeks
/// the same authored picture and final audio mix before output frame zero.
///
/// A test host supplies [runAsync] to execute IO and Snapshot rasterization.
/// Caller-injected resource and analysis services remain caller-owned.
Future<RenderManifest> renderVideo({
  required Video video,
  required Directory outDir,
  required ShellMount pumpWidget,
  required ShellFramePump pumpFrame,
  required SetViewSize setViewSize,
  ShellRunAsync runAsync = runAsyncDirectly,
  String compositionKey = 'render',
  int? frameCountOverride,
  int frameStart = 0,
  bool cacheEnabled = false,
  Directory? cacheRoot,
  Aspect? aspect,
  Quality? quality,
  Export? export,
  Time? posterTime,
  MediaResolver? resolver,
  SnapshotService? snapshotService,
  RenderCancellation? cancellation,
  BeatDetectionService? beatDetector,
  FrequencyAnalyzer? analyzer,
  String? defaultFontFamily,
  FrameCaptureService capture = const RepaintBoundaryCaptureService(),
  void Function(int completed, int total)? onProgress,
  void Function(int hits, int total)? onCacheReport,
}) async {
  final size = aspect?.sizeFor(video.width > video.height ? video.width : video.height);
  final width = size?.width ?? video.width;
  final height = size?.height ?? video.height;
  final frameCount = frameCountOverride ?? video.totalFrames;
  _guardUntrustedRender(width: width, height: height, frameCount: frameCount);
  setViewSize(width, height);
  final authoredPoster = (posterTime ?? video.poster)?.resolveFrames(
    TimeScopeData(fps: video.fps, startFrame: 0, durationFrames: video.totalFrames),
  );
  final relativePoster = authoredPoster == null ? null : authoredPoster - frameStart;
  Widget composition = Directionality(textDirection: TextDirection.ltr, child: video);
  if (defaultFontFamily != null) {
    composition = DefaultTextStyle.merge(
      style: TextStyle(fontFamily: defaultFontFamily),
      child: composition,
    );
  }
  final request = VideoRenderRequest(
    composition: composition,
    width: width,
    height: height,
    fps: video.fps,
    frameCount: frameCount,
    startFrame: frameStart,
    aspect: aspect,
    quality: quality,
    export: export,
    cancellation: cancellation,
    posterFrame: relativePoster != null && relativePoster >= 0 && relativePoster < frameCount
        ? relativePoster
        : null,
  ).withAuthoredOptions(authoredExport: video.export);
  final owned = resolver == null
      ? resolverScope(null, whenCancelled: cancellation?.whenCancelled)
      : null;
  final active = resolver ?? owned!.resolver;
  final counting = _CountingCaptureService(capture);
  try {
    final service = RenderService(
      capture: counting,
      media: active,
      cache: FrameCache(cacheRoot ?? FrameCache.defaultRoot()),
    );
    final result = await capture_aspect.render(
      composition: composition,
      aspect: aspect ?? Aspect.square,
      frameCount: frameCount,
      outDir: outDir,
      service: service,
      pumpWidget: pumpWidget,
      pumpFrame: pumpFrame,
      runAsync: runAsync,
      request: request,
      resolver: active,
      cacheEnabled: cacheEnabled,
      snapshotService: snapshotService,
      beatDetector: beatDetector,
      analyzer: analyzer,
      cancellation: cancellation,
      onProgress: onProgress,
      compositionKey: compositionKey,
    );
    onCacheReport?.call(cacheEnabled ? frameCount - counting.captures : 0, frameCount);
    return result.manifest;
  } finally {
    await owned?.dispose();
  }
}
