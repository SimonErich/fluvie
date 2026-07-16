import 'dart:async';

import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/media/media_providers_common.dart';
import 'package:fluvie/src/media/media_repository.dart';
import 'package:fluvie/src/media/runtime/clip_frame_cache.dart';
import 'package:fluvie/src/media/runtime/stale_temp_sweeper.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_frame_extraction_service.dart';
import 'package:fluvie/src/rendering/encoding/video_probe_service.dart';
import 'package:riverpod/riverpod.dart';

export 'package:fluvie/src/media/media_providers_common.dart';

/// The persistent clip-frame cache the native resolver serves extracted frames
/// from, or `null` when no user cache directory can be resolved (the resolver
/// then extracts afresh every run). Overridable with a per-test root.
final clipFrameCacheProvider = Provider<ClipFrameCache?>((ref) => ClipFrameCache.userCache());

/// The sweeper that reclaims staging directories orphaned by killed runs.
/// Overridable with a fake temp directory in tests.
final staleTempSweeperProvider = Provider<StaleTempSweeper>((ref) => StaleTempSweeper());

/// The media resolver used by the native render pipeline: a real
/// [MediaRepository] over the injected loader plus the clip probe/extraction
/// services, streaming clip frames through an on-disk [FileClipFrameStore] so a
/// full-resolution or long clip never has to hold every decoded frame in
/// memory, and serving them from the persistent [clipFrameCacheProvider] so an
/// unchanged clip is not re-extracted on every run. Overridable with a fake in
/// tests; `NoMediaResolver` stays exported as the deliberate media-less choice.
///
/// The store is dropped when [clipFrameStreamingProvider] is off, because the
/// streaming window is filled only by the capture loop's `prepareClipFrames`: a
/// caller with no loop (a live preview) must decode every planned frame up
/// front or paint's synchronous lookup misses.
///
/// Building the resolver also kicks off the orphan sweep: it is the one place
/// every native run passes through, it is off the render's critical path
/// (unawaited), and the sweep swallows its own errors, so a render never waits
/// on it or fails with it.
final mediaResolverProvider = Provider<MediaResolver>((ref) {
  unawaited(ref.watch(staleTempSweeperProvider).sweep());
  return MediaRepository(
    loader: ref.watch(mediaBytesLoaderProvider),
    probeService: ref.watch(videoProbeServiceProvider),
    frameExtractor: ref.watch(frameExtractionServiceProvider),
    clipFrameStore: ref.watch(clipFrameStreamingProvider) ? FileClipFrameStore() : null,
    clipFrameCache: ref.watch(clipFrameCacheProvider),
    maxClipDecodeEdge: ref.watch(clipDecodeMaxEdgeProvider),
  );
});
