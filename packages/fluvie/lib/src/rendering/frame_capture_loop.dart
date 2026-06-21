import 'package:flutter/widgets.dart' show GlobalKey;
import 'package:fluvie/src/rendering/capture/frame_capture_service.dart';
import 'package:fluvie/src/rendering/encoding/frame_store.dart';
import 'package:fluvie/src/rendering/io/render_sandbox.dart';
import 'package:fluvie/src/rendering/render_config.dart';

/// Pumps the tree to frame `n` and returns once that frame is fully built —
/// the host (a widget test, the capture harness, the off-screen web/mobile
/// driver) owns the pumping mechanics.
typedef FramePump = Future<void> Function(int frame);

/// Reports capture progress: [completed] of [total] frames are written.
///
/// Called once per frame after it is appended (a cache hit counts too), so the
/// count rises monotonically from `1` to `total`. Purely observational — it is
/// driven by the deterministic frame loop, reads no wall-clock, and never
/// affects a frame's bytes.
typedef ProgressCallback = void Function(int completed, int total);

/// The deterministic capture loop, shared by every render backend.
///
/// Runs `config.startFrame .. startFrame + frameCount - 1` in order, appending
/// each frame's RGBA bytes to [sink]. With a [store] active, a frame found under
/// `digest + index` is appended from cache without pumping; otherwise it is
/// pumped via [pump], captured under [boundaryKey], appended, and stored. A
/// cached entry whose byte length does not match the expected frame size is
/// treated as a miss and recaptured (the store is advisory). The frame is the
/// only clock and the sink is storage-agnostic, so the same loop drives a disk
/// file (desktop/mobile) or an in-memory buffer (web) identically.
Future<void> runFrameCaptureLoop({
  required RenderConfig config,
  required String digest,
  required FramePump pump,
  required GlobalKey boundaryKey,
  required CaptureSink sink,
  required FrameCaptureService capture,
  FrameStore? store,
  ProgressCallback? onProgress,
}) async {
  final frameBytes = config.width * config.height * 4;
  final useStore = config.cacheEnabled && store != null;
  final end = config.startFrame + config.frameCount;
  for (var frame = config.startFrame; frame < end; frame++) {
    final cached = useStore ? await store.lookup(digest, frame) : null;
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
      if (useStore) await store.store(digest, frame, raw.rgba);
    }
    // Report after the frame is appended (cache hit or fresh capture alike), so
    // a progress reader sees monotonically rising completion. Observational
    // only: it reads no clock and never changes a frame's bytes.
    onProgress?.call(frame - config.startFrame + 1, config.frameCount);
  }
}
