import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/media/runtime/image_resolve_cache.dart';
import 'package:fluvie/src/rendering/capture/raw_frame.dart';

/// Backing store for a clip's extracted source frames (raw RGBA), kept off the
/// Dart heap so the decoded window can stay small.
///
/// The `dart:io` `MediaRepository` backs this with files in a temp directory;
/// a resolver with no store decodes every frame up front instead (the browser
/// path). Frames are addressed by an opaque per-clip [String] key plus the
/// source-frame index, and [dispose] releases the whole store.
abstract interface class ClipFrameStore {
  /// Writes the RGBA bytes of [frame] for the clip keyed by [clipKey].
  Future<void> put(String clipKey, int frame, Uint8List rgba);

  /// Reads the RGBA bytes of [frame] for [clipKey], or null when absent.
  Future<Uint8List?> get(String clipKey, int frame);

  /// Releases every stored frame.
  Future<void> dispose();
}

/// How a clip maps composition frames to its source frames — the data
/// [ClipResolveCache.prepareClipFramesForComposition] resamples against.
typedef _ClipPlan = ({
  int windowStart,
  int windowLength,
  int compFps,
  int trimStartFrames,
  int trimEndFrames,
});

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

  /// Decode-all mode only: every decoded frame, keyed by source-frame index.
  final Map<MediaSource, Map<int, ui.Image>> clipFrames = {};

  // Streaming-mode state.
  final Map<MediaSource, _ClipPlan> _clipPlans = {};
  final Map<MediaSource, String> _clipKeys = {};
  final Map<MediaSource, Set<int>> _storedFrames = {};
  final LinkedHashMap<String, ui.Image> _window = LinkedHashMap<String, ui.Image>();
  int _clipKeyCounter = 0;

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

  /// Frames extracted per store round-trip in streaming mode — small, so the
  /// extraction never holds a whole clip's frames in memory at once.
  static const int _extractChunk = 8;

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
  Future<ClipMetadata> resolveClipMeta(MediaSource source) async {
    final cached = clipMeta[source];
    if (cached != null) return cached;
    return clipMeta[source] = await probeClipSource(source);
  }

  /// Resolves [sourceFrames] of [source]: probes if needed, then in streaming
  /// mode extracts the missing frames in small chunks into the store, or in
  /// decode-all mode decodes them up front.
  Future<void> resolveClipFrames(MediaSource source, Iterable<int> sourceFrames) async {
    final meta = await resolveClipMeta(source);
    final store = clipFrameStore;
    if (store == null) {
      final frames = clipFrames.putIfAbsent(source, () => {});
      final missing = [
        for (final i in sourceFrames)
          if (!frames.containsKey(i)) i,
      ];
      if (missing.isEmpty) return;
      final extracted = await extractClipFrames(source, missing, meta);
      for (final entry in extracted.entries) {
        frames[entry.key] = await _decodeRawFrame(source, entry.value);
      }
      return;
    }
    final stored = _storedFrames.putIfAbsent(source, () => <int>{});
    final key = _keyFor(source);
    final missing = [
      for (final i in sourceFrames)
        if (!stored.contains(i)) i,
    ]..sort();
    for (var i = 0; i < missing.length; i += _extractChunk) {
      final chunk = missing.sublist(i, math.min(i + _extractChunk, missing.length));
      final extracted = await extractClipFrames(source, chunk, meta);
      for (final entry in extracted.entries) {
        await store.put(key, entry.key, entry.value.rgba);
        stored.add(entry.key);
      }
    }
  }

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
  }) {
    _clipPlans[source] = (
      windowStart: windowStart,
      windowLength: windowLength,
      compFps: compFps,
      trimStartFrames: trimStartFrames,
      trimEndFrames: trimEndFrames,
    );
  }

  /// Streaming decode-ahead: decodes (into the bounded window) the frame every
  /// registered clip paints on composition frame [compFrame], loading it from
  /// the store and evicting the least-recently-used beyond the window capacity.
  /// A no-op without a store or before any plan is registered.
  ///
  /// It warms a frame for *every* registered clip, not just those whose scene is
  /// on screen: a clip's painter rebuilds on every composition frame and the
  /// resampler clamps an off-window frame to the clip's first or last source
  /// frame, so an off-screen clip still reads a (clamped) frame that paint looks
  /// up synchronously. Warming exactly what the painter resamples keeps the
  /// streaming window a hit for every paint, matching the decode-all path.
  Future<void> prepareClipFramesForComposition(int compFrame) async {
    final store = clipFrameStore;
    if (store == null || _clipPlans.isEmpty) return;
    for (final entry in _clipPlans.entries) {
      final meta = clipMeta[entry.key];
      if (meta == null) continue;
      await _ensureDecoded(entry.key, _resample(compFrame, entry.value, meta.fps), store);
    }
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
  ui.Image decodedClipFrameLookup(MediaSource source, int sourceFrame) {
    assertResolved('decodedClipFrame');
    if (clipFrameStore == null) {
      final image = clipFrames[source]?[sourceFrame];
      if (image == null) {
        throw FluvieRenderException(
          '$runtimeType has no extracted clip frame $sourceFrame for "$source". '
          'Was it included in the frames pre-resolved with preResolveClip?',
        );
      }
      return image;
    }
    final image = _window['${_keyFor(source)}#$sourceFrame'];
    if (image == null) {
      throw FluvieRenderException(
        '$runtimeType has no clip frame $sourceFrame for "$source" in the decode '
        'window. The capture loop must call prepareClipFrames(frame) before it '
        'pumps a frame that paints this clip.',
      );
    }
    return image;
  }

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
    for (final image in _window.values) {
      image.dispose();
    }
    _window.clear();
    _clipPlans.clear();
    _clipKeys.clear();
    _storedFrames.clear();
  }

  /// Ensures [sourceFrame] of [source] is decoded in the window, loading it from
  /// [store] and decoding on a miss, then evicting the LRU beyond capacity.
  Future<void> _ensureDecoded(
    MediaSource source,
    int sourceFrame,
    ClipFrameStore store,
  ) async {
    final lruKey = '${_keyFor(source)}#$sourceFrame';
    final present = _window.remove(lruKey);
    if (present != null) {
      _window[lruKey] = present; // touch: move to most-recently-used.
      return;
    }
    final rgba = await store.get(_keyFor(source), sourceFrame);
    if (rgba == null) {
      throw FluvieRenderException(
        '$runtimeType has no stored clip frame $sourceFrame for "$source". '
        'Was it included in the frames pre-resolved with preResolveClip?',
      );
    }
    final meta = clipMeta[source]!;
    _window[lruKey] = await _decodeRgba(source, rgba, meta.width, meta.height);
    // Every registered clip warms one frame per composition frame, so the window
    // must hold at least that many at once or a clip's just-warmed frame would be
    // evicted before paint reads it.
    final capacity = math.max(clipWindowCapacity, _clipPlans.length);
    while (_window.length > capacity) {
      _window.remove(_window.keys.first)!.dispose();
    }
  }

  int _resample(int compFrame, _ClipPlan plan, double srcFps) {
    final advanced = ((compFrame - plan.windowStart) / plan.compFps * srcFps).floor();
    final raw = advanced + plan.trimStartFrames;
    return math.max(plan.trimStartFrames, math.min(raw, plan.trimEndFrames - 1));
  }

  String _keyFor(MediaSource source) =>
      _clipKeys.putIfAbsent(source, () => 'clip${_clipKeyCounter++}');

  Future<ui.Image> _decodeRawFrame(MediaSource source, RawFrame raw) =>
      _decodeRgba(source, raw.rgba, raw.width, raw.height);

  Future<ui.Image> _decodeRgba(
    MediaSource source,
    Uint8List rgba,
    int width,
    int height,
  ) async {
    try {
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        rgba,
        width,
        height,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
      return await completer.future;
    } on Object catch (error) {
      // coverage:ignore-line: defensive decode-failure wrap; valid clip frames decode cleanly
      throw FluvieRenderException('Failed to decode clip frame of "$source": $error.');
    }
  }
}
