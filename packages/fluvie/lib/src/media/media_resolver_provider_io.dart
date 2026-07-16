import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/media/media_providers_common.dart';
import 'package:fluvie/src/media/media_repository.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_frame_extraction_service.dart';
import 'package:fluvie/src/rendering/encoding/video_probe_service.dart';
import 'package:riverpod/riverpod.dart';

export 'package:fluvie/src/media/media_providers_common.dart';

/// The media resolver used by the native render pipeline: a real
/// [MediaRepository] over the injected loader plus the clip probe/extraction
/// services, streaming clip frames through an on-disk [FileClipFrameStore] so a
/// full-resolution or long clip never has to hold every decoded frame in
/// memory. Overridable with a fake in tests; `NoMediaResolver` stays exported
/// as the deliberate media-less choice.
///
/// The store is dropped when [clipFrameStreamingProvider] is off, because the
/// streaming window is filled only by the capture loop's `prepareClipFrames`: a
/// caller with no loop (a live preview) must decode every planned frame up
/// front or paint's synchronous lookup misses.
final mediaResolverProvider = Provider<MediaResolver>(
  (ref) => MediaRepository(
    loader: ref.watch(mediaBytesLoaderProvider),
    probeService: ref.watch(videoProbeServiceProvider),
    frameExtractor: ref.watch(frameExtractionServiceProvider),
    clipFrameStore: ref.watch(clipFrameStreamingProvider) ? FileClipFrameStore() : null,
    maxClipDecodeEdge: ref.watch(clipDecodeMaxEdgeProvider),
  ),
);
