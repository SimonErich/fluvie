import 'dart:async';
import 'dart:ui' as ui;

import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/media/runtime/image_resolve_cache.dart';
import 'package:fluvie/src/rendering/capture/raw_frame.dart';

/// The shared clip cache behind every [MediaResolver] that decodes video clips:
/// probe a source once for its [ClipMetadata], extract the source frames a
/// render needs, decode each to a `ui.Image`, and serve them synchronously.
///
/// It owns the platform-agnostic cache, frame diffing, pixel decode, and the
/// pre-resolve read guard, deferring the *how* of probing and extracting to
/// [probeClipSource] and [extractClipFrames]. The `dart:io` `MediaRepository`
/// implements those with ffprobe and ffmpeg; the browser resolver implements
/// them with WebCodecs. Both reuse this cache through the shared
/// [ImageResolveCache] base, so the clip decode path is written once.
mixin ClipResolveCache on ImageResolveCache {
  /// The probed metadata for each clip source, cached after the first probe.
  final Map<MediaSource, ClipMetadata> clipMeta = {};

  /// The decoded frames for each clip source, keyed by source-frame index.
  final Map<MediaSource, Map<int, ui.Image>> clipFrames = {};

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

  /// Resolves [sourceFrames] of [source]: probes the metadata if needed, then
  /// extracts and decodes only the frames not already cached.
  Future<void> resolveClipFrames(MediaSource source, Iterable<int> sourceFrames) async {
    final meta = await resolveClipMeta(source);
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

  /// The synchronous frame lookup: asserts the pre-pass ran, then returns the
  /// cached frame or throws a typed error naming the missing [sourceFrame].
  ui.Image decodedClipFrameLookup(MediaSource source, int sourceFrame) {
    assertResolved('decodedClipFrame');
    final image = clipFrames[source]?[sourceFrame];
    if (image == null) {
      throw FluvieRenderException(
        '$runtimeType has no extracted clip frame $sourceFrame for "$source". '
        'Was it included in the frames pre-resolved with preResolveClip?',
      );
    }
    return image;
  }

  /// Disposes every decoded clip frame and clears the cache. Idempotent: a
  /// second call has nothing left to dispose.
  void disposeClipFrames() {
    for (final frames in clipFrames.values) {
      for (final image in frames.values) {
        image.dispose();
      }
    }
    clipFrames.clear();
  }

  Future<ui.Image> _decodeRawFrame(MediaSource source, RawFrame raw) async {
    try {
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        raw.rgba,
        raw.width,
        raw.height,
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
