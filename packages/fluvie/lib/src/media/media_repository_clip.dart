part of 'media_repository.dart';

/// The `dart:io` half of [MediaRepository]'s clip path: materialize the source
/// to a local file the probe and extractor can read by path. The cache, frame
/// diffing, decode, and lookups live in the shared [ClipResolveCache] mixin;
/// `probeClipSource` and `extractClipFrames` (in the main class) call this.
extension _ClipResolution on MediaRepository {
  /// Materializes [source], probes it for [ClipMetadata], and records the
  /// decoder its frames must be extracted with. The [ClipResolveCache] caches
  /// the result, so this runs once per source.
  Future<ClipMetadata> _probeClipSource(MediaSource source) async {
    final probe = probeService;
    if (probe == null) {
      throw FluvieRenderException(
        'MediaRepository cannot probe clip "$source" without a VideoProbeService. '
        'Wire it through the providers.',
      );
    }
    final path = await _materializeClip(source);
    final result = await probe.probe(path);
    final decoder = _decoderFor(result);
    if (decoder != null) _clipDecoders[source] = decoder;
    return (
      fps: result.fps,
      frameCount: result.nbFrames,
      width: result.width,
      height: result.height,
      hasAudio: result.hasAudio,
    );
  }

  /// Extracts the [sourceFrames] of the already-materialized [source] at the clip
  /// [meta] dimensions through the ffmpeg [FrameExtractionService], serving
  /// whatever the persistent [MediaRepository.clipFrameCache] already holds.
  ///
  /// This is the one choke point both resolve modes reach (decode-all and
  /// streaming both call `extractClipFrames`), so the cache is consulted here
  /// once and a preview and a render both benefit. ffmpeg spawns a process per
  /// frame, so a hit is worth several orders of magnitude here.
  Future<Map<int, RawFrame>> _extractClipFrames(
    MediaSource source,
    List<int> sourceFrames,
    ClipMetadata meta,
  ) async {
    final extractor = frameExtractor;
    if (extractor == null) {
      throw FluvieRenderException(
        'MediaRepository cannot resolve clip "$source" without a '
        'FrameExtractionService. Wire it through the providers.',
      );
    }
    final cache = clipFrameCache;
    final key = _clipCacheKey(source, meta);
    final cached = cache == null || key == null
        ? const <int, RawFrame>{}
        : await _cachedClipFrames(cache, key, sourceFrames, meta);
    final missing = [
      for (final index in sourceFrames)
        if (!cached.containsKey(index)) index,
    ];
    if (missing.isEmpty) {
      if (cache != null && key != null) await cache.markUsed(key);
      return cached;
    }
    final extracted = await extractor.extractFrames(
      Uri.file(_clipPaths[source]!),
      missing,
      width: meta.width,
      height: meta.height,
      decoder: _clipDecoders[source],
    );
    if (cache != null && key != null) await _storeClipFrames(cache, key, extracted);
    return {...cached, ...extracted};
  }

  /// The cache key for [source] decoded at the [meta] dimensions, or null when
  /// the source has not been content-hashed.
  ///
  /// The hash comes from the image pre-pass ([MediaRepository.preResolveAll]
  /// content-hashes clip sources without decoding them), which always runs
  /// before the clip pre-pass. A caller that skips it simply runs uncached
  /// rather than keying on the materialized path, which is a fresh temp path
  /// every run and would never hit.
  String? _clipCacheKey(MediaSource source, ClipMetadata meta) {
    final cache = clipFrameCache;
    final contentHash = resolved[source]?.contentHash;
    if (cache == null || contentHash == null) return null;
    return cache.clipKey(
      contentHash: contentHash,
      width: meta.width,
      height: meta.height,
      decoder: _clipDecoders[source],
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

  /// The decoder [result]'s source must be extracted with, or null for the
  /// extractor's default.
  ///
  /// VP9 codes alpha as a second layer that only `libvpx-vp9` reads: ffmpeg's
  /// native `vp9` decoder silently drops it and the clip composites over black.
  /// VP9 without alpha stays on the native decoder, which is much faster.
  String? _decoderFor(VideoProbeResult result) =>
      result.codec == 'vp9' && result.hasAlpha ? 'libvpx-vp9' : null;

  /// Loads the clip bytes once and writes them to a temp file the probe and
  /// extractor can read by path; cached per source.
  Future<String> _materializeClip(MediaSource source) async {
    final existing = _clipPaths[source];
    if (existing != null) return existing;
    final bytes = await loader.load(source);
    final dir = await Directory.systemTemp.createTemp('fluvie_clip_src_');
    _stagedDirs.add(dir);
    final file = File('${dir.path}/clip.mp4');
    await file.writeAsBytes(bytes);
    return _clipPaths[source] = file.path;
  }
}

/// A [ClipFrameStore] that keeps each extracted clip frame in its own file
/// under a temp directory — the on-device/desktop store, so a clip's frames
/// live on disk instead of the heap and the resolver only ever decodes the
/// small window the current composition frame needs.
///
/// The directory is created lazily on the first [put] (a render with no clip
/// never makes one) and removed wholesale by [dispose]. Frames are addressed by
/// the resolver's opaque per-clip key plus the source-frame index; the keys are
/// generated, never attacker-controlled, so the paths are safe.
final class FileClipFrameStore implements ClipFrameStore {
  Directory? _dir;

  Future<Directory> _ensureDir() async =>
      _dir ??= await Directory.systemTemp.createTemp('fluvie_clip_frames_');

  @override
  Future<void> put(String clipKey, int frame, Uint8List rgba) async {
    final dir = await _ensureDir();
    final file = File('${dir.path}/$clipKey/$frame.rgba');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(rgba);
  }

  @override
  Future<Uint8List?> get(String clipKey, int frame) async {
    final dir = _dir;
    if (dir == null) return null;
    final file = File('${dir.path}/$clipKey/$frame.rgba');
    if (!file.existsSync()) return null;
    return file.readAsBytes();
  }

  @override
  Future<void> dispose() async {
    final dir = _dir;
    _dir = null;
    if (dir != null && dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }
}
