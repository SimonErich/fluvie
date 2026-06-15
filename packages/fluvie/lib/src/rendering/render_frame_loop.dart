part of 'render_service.dart';

/// The capture loop of [RenderService.captureToDirectory], extracted to a
/// part file to keep the service under the file-size budget.
///
/// Runs `config.startFrame .. startFrame + frameCount - 1` in order. With
/// caching active a frame found under `digest + index` is appended from cache
/// without pumping; otherwise the frame is pumped, captured, appended and
/// stored. A cached entry whose byte length does not match the expected frame
/// size is treated as a miss and recaptured (the cache is advisory).
Future<void> _runFrameLoop({
  required RenderConfig config,
  required String digest,
  required FramePump pump,
  required GlobalKey boundaryKey,
  required IOSink sink,
  required FrameCaptureService capture,
  required FrameCache? cache,
  ProgressCallback? onProgress,
}) async {
  final frameBytes = config.width * config.height * 4;
  final useCache = config.cacheEnabled && cache != null;
  final end = config.startFrame + config.frameCount;
  for (var frame = config.startFrame; frame < end; frame++) {
    final key = useCache ? cache.frameKey(digest, frame) : null;
    final cached = key == null ? null : await cache!.lookup(key);
    if (cached != null && cached.length == frameBytes) {
      sink.add(cached);
    } else {
      await pump(frame);
      final raw = await capture.capture(
        boundaryKey: boundaryKey,
        frameIndex: frame,
        width: config.width,
        height: config.height,
      );
      sink.add(raw.rgba);
      if (key != null) await cache!.store(key, raw.rgba);
    }
    // Report after the frame is appended (cache hit or fresh capture alike), so
    // a progress reader sees monotonically rising completion. Observational
    // only: it reads no clock and never changes a frame's bytes.
    onProgress?.call(frame - config.startFrame + 1, config.frameCount);
  }
}
