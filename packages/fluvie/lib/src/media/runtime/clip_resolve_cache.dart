import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/elements/runtime/clip_resampler.dart';
import 'package:fluvie/src/media/runtime/clip_frame_store.dart';
import 'package:fluvie/src/media/runtime/image_resolve_cache.dart';
import 'package:fluvie/src/rendering/capture/raw_frame.dart';
import 'package:fluvie_media/fluvie_media.dart' show MediaTimeline;

export 'package:fluvie/src/media/runtime/clip_frame_store.dart' show ClipFrameStore;

part 'clip_resolve_cache_window.dart';
part 'clip_resolve_cache_resolution.dart';

/// The shared clip cache behind every [MediaResolver] that decodes video clips:
/// probe a source once for its [ClipMetadata], extract the source frames a
/// render needs, and serve a decoded `ui.Image` synchronously to paint.
///
/// It has two modes, chosen by [clipFrameStore]:
///
/// - **Streaming** (a non-null store — the on-device/desktop path): extracted
///   frames are written to the store (off-heap) in small chunks, and only a
///   bounded window of *decoded* frames is held. The capture loop calls
///   [prepareClipFramesForComposition] before each frame to decode just the
///   frames that frame paints (loaded from the store) and evict the
///   least-recently-used beyond [clipWindowCapacity]. A full-resolution or long
///   clip therefore never needs its whole decoded self in memory.
/// - **Decode-all** (a null store — the browser path): every requested frame is
///   decoded up front into [clipFrames] and served directly. Simpler, used
///   where a disk store is unavailable.
///
/// The *how* of probing and extracting defers to [probeClipSource] and
/// [extractClipFrames] (ffmpeg/MediaCodec/WebCodecs); this mixin owns the
/// platform-agnostic cache, store orchestration, decode, and read guard.
mixin ClipResolveCache on ImageResolveCache {
  /// The probed metadata for each clip source, cached after the first probe.
  final Map<MediaSource, ClipMetadata> clipMeta = {};

  /// Optional exact display clocks published by a probe or browser decoder.
  final Map<MediaSource, MediaTimeline> clipTimelines = {};

  /// Decode-all mode only: every decoded frame, keyed by source-frame index.
  final Map<MediaSource, Map<int, ui.Image>> clipFrames = {};

  final _ClipStreamer _streamer = _ClipStreamer();

  /// The store extracted frames stream through, or null to decode every frame
  /// up front into [clipFrames]. Defaults to null (decode-all); the on-device
  /// resolver overrides it with a disk-backed store.
  ClipFrameStore? get clipFrameStore => null;

  /// How many decoded frames the streaming window keeps before evicting the
  /// least-recently-used. The effective floor is raised to the number of
  /// registered clips when that is larger (every clip warms one frame per
  /// composition frame), so this is the decode-ahead slack above that; the
  /// default covers dense collages with room to spare.
  int get clipWindowCapacity => 16;

  /// The longest side a clip's raster is decoded at in **decode-all mode**, or
  /// null (the default) to decode at the source's own resolution.
  ///
  /// Decode-all holds every planned frame at once (~8.3 MB per full-HD frame),
  /// so a live preview sets a bound and a render leaves it null;
  /// `fluvie_mobile_encoder`'s probe caps the same way for the same reason. It
  /// never touches the cached [ClipMetadata], which keeps the source's own facts
  /// so paint can recover the clip's true layout size. Streaming mode ignores it
  /// (its window already bounds memory, and its store's rasters must match the
  /// metadata to decode back).
  int? get maxClipDecodeEdge => null;

  /// Probes [source] for its fps, frame count, and dimensions. Called at most
  /// once per source; [resolveClipMeta] caches the result.
  Future<ClipMetadata> probeClipSource(MediaSource source);

  /// Extracts the [sourceFrames] of [source] (already known to be missing) at
  /// the clip [meta] dimensions, each as a [RawFrame] keyed by its index.
  Future<Map<int, RawFrame>> extractClipFrames(
    MediaSource source,
    List<int> sourceFrames,
    ClipMetadata meta,
  );

  /// Returns the [ClipMetadata] for [source], probing and caching it on the
  /// first call. Safe to call repeatedly: the probe runs once.
  ///
  /// The cached metadata is always the source's own, never the decode bound's:
  /// paint reads these dimensions to recover the clip's true layout size.
  Future<ClipMetadata> resolveClipMeta(MediaSource source) async {
    final cached = clipMeta[source];
    if (cached != null) return cached;
    return clipMeta[source] = await probeClipSource(source);
  }

  /// Resolves [sourceFrames] of [source]: probes if needed, then in streaming
  /// mode extracts the missing frames in small chunks into the store, or in
  /// decode-all mode decodes them up front at the [maxClipDecodeEdge] bound.
  ///
  /// The bound applies to decode-all only. Streaming's window already bounds its
  /// memory, and its store keeps raw bytes whose dimensions are read back from
  /// the metadata — so a bound there would decode the stored rasters at the
  /// wrong size.
  Future<void> resolveClipFrames(MediaSource source, Iterable<int> sourceFrames) =>
      _resolveClipFrames(source, sourceFrames);

  /// Records [source]'s composition→source frame mapping for the streaming
  /// decode-ahead (the `ClipFramePreparer.registerClipPlan` contract).
  /// Idempotent.
  void registerClipPlan({
    required MediaSource source,
    required int windowStart,
    required int windowLength,
    required int compFps,
    required int trimStartFrames,
    required int trimEndFrames,
    double trimStartOffsetFrames = 0,
    double trimEndOffsetFrames = 0,
    double speed = 1,
    List<double>? sourceTimeMap,
  }) {
    _streamer.registerPlan(source, (
      windowStart: windowStart,
      windowLength: windowLength,
      compFps: compFps,
      trimStartFrames: trimStartFrames,
      trimEndFrames: trimEndFrames,
      trimStartOffsetFrames: trimStartOffsetFrames,
      trimEndOffsetFrames: trimEndOffsetFrames,
      speed: speed,
      sourceTimeMap: sourceTimeMap,
    ));
  }

  /// Streaming decode-ahead: decodes (into the bounded window) the frame every
  /// registered clip paints on composition frame [compFrame], loading it from
  /// the store and evicting the least-recently-used beyond the window capacity.
  /// A no-op without a store or before any plan is registered.
  ///
  /// Future windows need only probed geometry. Finished windows retain their
  /// final visible picture so a direct seek into a held transition is exact.
  Future<void> prepareClipFramesForComposition(int compFrame) async {
    final store = clipFrameStore;
    if (store == null || !_streamer.hasPlans) return;
    await _streamer.prepareForComposition(
      compFrame: compFrame,
      meta: clipMeta,
      timelines: clipTimelines,
      store: store,
      windowCapacity: clipWindowCapacity,
      debugOwner: '$runtimeType',
    );
  }

  /// The synchronous metadata lookup: asserts the pre-pass ran, then returns the
  /// cached [ClipMetadata] or throws a typed error naming [source].
  ClipMetadata clipMetadataLookup(MediaSource source) {
    assertResolved('clipMetadataFor');
    final meta = clipMeta[source];
    if (meta == null) {
      throw FluvieRenderException(
        '$runtimeType has no clip metadata for "$source". '
        'Was it pre-resolved with preResolveClip before the frame loop?',
      );
    }
    return meta;
  }

  /// The synchronous frame lookup paint uses: asserts the pre-pass ran, then
  /// returns the decoded frame (from the streaming window or the decode-all
  /// cache) or throws a typed error naming the missing [sourceFrame].
  ui.Image decodedClipFrameLookup(MediaSource source, int sourceFrame) =>
      _decodedClipFrameLookup(source, sourceFrame);

  /// Evicts decode-all preview frames outside the bounded ready window. Capture
  /// does not call this; its planned frames remain exact for the whole render.
  void retainPreviewClipFrames(Map<MediaSource, Set<int>> retained) =>
      _retainPreviewClipFrames(retained);

  /// Disposes every decoded clip frame (decode-all cache and streaming window)
  /// and clears the per-clip state. Idempotent. The [clipFrameStore] itself is
  /// owned and disposed by the resolver that provides it.
  void disposeClipFrames() {
    for (final frames in clipFrames.values) {
      for (final image in frames.values) {
        image.dispose();
      }
    }
    clipFrames.clear();
    clipTimelines.clear();
    _streamer.dispose();
  }
}
