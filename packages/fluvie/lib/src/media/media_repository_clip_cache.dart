part of 'media_repository.dart';

/// Persistent decoded pixels are reusable only when their extractor is known.
extension _ClipPersistence on MediaRepository {
  Future<String?> _resolveExtractionCacheIdentity() async {
    final extractor = frameExtractor;
    if (extractor case final FrameExtractionCacheIdentity identified) {
      return identified.cacheIdentity;
    }
    return null;
  }

  /// The cache key for [source] decoded at the [meta] dimensions, or null when
  /// the source has not been content-hashed.
  ///
  /// The hash comes from the image pre-pass ([MediaRepository.preResolveAll]
  /// content-hashes clip sources without decoding them), which always runs
  /// before the clip pre-pass. A caller that skips it simply runs uncached
  /// rather than keying on the materialized path, which is a fresh temp path
  /// every run and would never hit.
  Future<String?> _clipCacheKey(MediaSource source, ClipMetadata meta) async {
    final cache = clipFrameCache;
    final contentHash = resolved[source]?.contentHash;
    if (cache == null || contentHash == null) return null;
    final identity = await _extractionCacheIdentity;
    if (identity == null || identity.trim().isEmpty) return null;
    return cache.clipKey(
      contentHash: contentHash,
      width: meta.width,
      height: meta.height,
      decoder: _clipDecoders[source],
      extractionIdentity: identity,
    );
  }

  /// The subset of [sourceFrames] [cache] already holds under [key], rebuilt as
  /// [RawFrame]s at the [meta] decode dimensions the key names.
  Future<Map<int, RawFrame>> _cachedClipFrames(
    ClipFrameCache cache,
    String key,
    List<int> sourceFrames,
    ClipMetadata meta,
  ) async {
    final byteLength = meta.width * meta.height * 4;
    final hits = <int, RawFrame>{};
    for (final index in sourceFrames) {
      final rgba = await cache.get(key, index, byteLength: byteLength);
      if (rgba == null) continue;
      hits[index] = RawFrame(
        frameIndex: index,
        width: meta.width,
        height: meta.height,
        rgba: rgba,
      );
    }
    return hits;
  }

  /// Stores every freshly extracted frame of [frames] under [key], then bounds
  /// the cache. Sweeping here (after a write) and not on reads keeps the hit
  /// path free of directory walks.
  Future<void> _storeClipFrames(ClipFrameCache cache, String key, Map<int, RawFrame> frames) async {
    for (final entry in frames.entries) {
      await cache.put(key, entry.key, entry.value.rgba);
    }
    await cache.sweep();
  }
}
