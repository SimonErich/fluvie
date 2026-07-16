import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fluvie/src/core/hash/fnv1a.dart';
import 'package:fluvie/src/media/runtime/user_cache_root.dart';

/// Persists extracted clip frames (raw RGBA) across runs, keyed by what
/// actually determines the pixels, so an unchanged clip is decoded once ever
/// instead of once per run.
///
/// The ffmpeg extractor spawns a process per frame, so a 106-frame clip costs
/// ~106 process spawns on every cold run. That is the placeholder a live
/// preview shows on each hot restart. Entries live under a stable user cache
/// directory (never the system temp directory), so a hot restart, a later
/// render, and a crashed run all share them.
///
/// **The key covers the decode, not just the source.** A preview decodes at a
/// proxy bound (`maxClipDecodeEdge`) while a render decodes at full source
/// resolution, and a VP9-with-alpha source must decode through `libvpx-vp9`
/// while everything else takes the extractor's default. Keying on content alone
/// would serve a preview's 720x404 raster to a full-resolution render, so
/// [clipKey] folds in the decode width, height, and decoder. See [clipKey].
///
/// The cache is bounded by [maxBytes] and evicted LRU by mtime, whole clip key
/// at a time: a half-evicted clip re-extracts anyway, so evicting individual
/// frames buys nothing. [sweep] runs after writes, never on reads.
final class ClipFrameCache {
  /// Creates a cache rooted at [root] (created lazily on the first [put]),
  /// holding at most [maxBytes] of frames.
  ClipFrameCache(this.root, {this.maxBytes = defaultMaxBytes});

  /// The default cache under the user cache root, or `null` when the platform's
  /// base directory cannot be resolved (no `HOME` / `LOCALAPPDATA`) — the
  /// caller then runs uncached rather than falling back to a temp directory.
  ///
  /// [environment] and [windows] default to the host's and exist so tests can
  /// resolve any platform's layout hermetically.
  static ClipFrameCache? userCache({
    Map<String, String>? environment,
    bool? windows,
    int maxBytes = defaultMaxBytes,
  }) {
    final base = userCacheRoot(environment: environment, windows: windows);
    return base == null ? null : ClipFrameCache(Directory('$base/clip_frames'), maxBytes: maxBytes);
  }

  /// The directory holding one subdirectory per clip key, each holding one file
  /// per cached frame.
  final Directory root;

  /// The total frame bytes the cache keeps before [sweep] evicts.
  final int maxBytes;

  /// 2 GiB: roughly 240 full-HD RGBA frames, or a couple of hours of proxy
  /// preview frames — enough that the clips a project works with day to day
  /// stay warm, and small enough that the cache cannot become the disk-filling
  /// bug it exists to prevent. Frames are raw RGBA, so this is deliberately
  /// generous compared to the encoded sources it caches.
  static const int defaultMaxBytes = 2 * 1024 * 1024 * 1024;

  /// The exact shape [clipKey] produces: 16 lower-case hex characters
  /// (FNV-1a-64), so it is path-safe by construction.
  static final RegExp _keyPattern = RegExp(r'^[0-9a-f]{16}$');

  /// The cache key for a clip whose bytes hash to [contentHash], decoded to
  /// [width] x [height] through [decoder] (null: the extractor's default).
  ///
  /// [contentHash] must be the source's own content hash, the one the image
  /// pre-pass already recorded in `ImageResolveCache.resolved` — never its
  /// path. The clip is materialized to a fresh temp directory every run, so its
  /// path differs every run and would never hit.
  ///
  /// The decode dimensions and the decoder are part of the key because they
  /// change the pixels: the same source decoded at a preview's proxy bound and
  /// at full render resolution are different rasters, and VP9 alpha survives
  /// only through `libvpx-vp9`.
  String clipKey({
    required String contentHash,
    required int width,
    required int height,
    String? decoder,
  }) => fnv1a64Hex(utf8.encode('$contentHash:$width:$height:${decoder ?? ''}'));

  /// The cached RGBA bytes of [frame] under [clipKey], or `null` on a miss.
  ///
  /// [byteLength] is the exact payload a hit must hold (`width * height * 4`
  /// for the decode this key names). A file of any other length is a truncated
  /// write from a killed run and reads as a miss, so a crash mid-write cannot
  /// poison the cache: the next extraction overwrites it. An unreadable entry
  /// is a miss for the same reason — the caller extracts instead.
  ///
  /// Throws an [ArgumentError] when [clipKey] is not the shape [clipKey]
  /// produces.
  Future<Uint8List?> get(String clipKey, int frame, {required int byteLength}) async {
    _checkKey(clipKey);
    try {
      final file = _frameFile(clipKey, frame);
      if (!file.existsSync()) return null;
      final bytes = await file.readAsBytes();
      return bytes.length == byteLength ? bytes : null;
      // coverage:ignore-start defensive arm an entry that exists yet cannot be read needs a permission error no portable unit test can produce
    } on FileSystemException {
      return null;
    }
    // coverage:ignore-end
  }

  /// Writes the RGBA bytes of [frame] under [clipKey], creating [root] when
  /// needed. Call [sweep] once after a batch of writes.
  ///
  /// Non-fatal by contract: a cache that cannot be written (a read-only or
  /// unwritable root) must never fail a render, so a filesystem error here is
  /// swallowed and the run simply stays cold.
  ///
  /// Throws an [ArgumentError] when [clipKey] is not the shape [clipKey]
  /// produces.
  Future<void> put(String clipKey, int frame, Uint8List rgba) async {
    _checkKey(clipKey);
    try {
      final file = _frameFile(clipKey, frame);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(rgba, flush: true);
    } on FileSystemException {
      // Best effort: an unwritable cache costs speed, never a render.
    }
  }

  /// Records that [clipKey] was served, refreshing its LRU recency.
  ///
  /// Recency is the newest mtime under the clip key's directory, and a read
  /// does not move any mtime — so a clip that only ever hits would look like
  /// the coldest entry in the cache and evict first. This writes an empty
  /// `used` marker (it adds no bytes to the size bound) to move it. Non-fatal:
  /// a failed marker costs recency, never a render.
  Future<void> markUsed(String clipKey) async {
    _checkKey(clipKey);
    try {
      final marker = File('${root.path}/$clipKey/used');
      if (marker.parent.existsSync()) await marker.writeAsBytes(const []);
      // coverage:ignore-start defensive arm the clip dir exists so only a permission error reaches this which no portable unit test can produce
    } on FileSystemException {
      // Best effort: recency is an optimisation, not correctness.
    }
    // coverage:ignore-end
  }

  /// Evicts whole clip keys, least-recently-used first, until the cache holds
  /// at most [maxBytes]. A no-op while the cache is under the bound.
  ///
  /// Non-fatal by contract: a cache that cannot be swept (a concurrent run
  /// deleting the same key, a read-only root) must never fail a render, so
  /// every filesystem error here is swallowed.
  Future<void> sweep() async {
    try {
      if (!root.existsSync()) return;
      final entries = [
        for (final entity in root.listSync())
          if (entity is Directory) _measure(entity),
      ]..sort((a, b) => a.usedAt.compareTo(b.usedAt));
      var total = entries.fold(0, (sum, entry) => sum + entry.bytes);
      for (final entry in entries) {
        if (total <= maxBytes) return;
        entry.dir.deleteSync(recursive: true);
        total -= entry.bytes;
      }
      // coverage:ignore-start defensive arm reaching it needs a concurrent run deleting the same key or an unreadable root neither of which a unit test can stage
    } on FileSystemException {
      // Best effort: an unsweepable cache is over budget, not broken.
    }
    // coverage:ignore-end
  }

  /// One clip key's total bytes and newest mtime (its LRU recency).
  _CacheEntry _measure(Directory dir) {
    var bytes = 0;
    var usedAt = DateTime.fromMillisecondsSinceEpoch(0);
    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      final stat = entity.statSync();
      bytes += stat.size;
      if (stat.modified.isAfter(usedAt)) usedAt = stat.modified;
    }
    return _CacheEntry(dir, bytes, usedAt);
  }

  File _frameFile(String clipKey, int frame) => File('${root.path}/$clipKey/$frame.rgba');

  static void _checkKey(String key) {
    if (!_keyPattern.hasMatch(key)) {
      throw ArgumentError.value(
        key,
        'clipKey',
        'must be 16 lower-case hex characters as produced by clipKey',
      );
    }
  }
}

/// One measured clip key directory: how much it holds and when it was last used.
final class _CacheEntry {
  const _CacheEntry(this.dir, this.bytes, this.usedAt);

  final Directory dir;
  final int bytes;
  final DateTime usedAt;
}
