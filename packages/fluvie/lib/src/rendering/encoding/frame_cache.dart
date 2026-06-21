import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:fluvie/src/rendering/encoding/content_hash.dart';
import 'package:fluvie/src/rendering/encoding/frame_store.dart';
import 'package:riverpod/riverpod.dart';

/// Persists captured frames on disk so an unchanged render replays from cache
/// instead of re-capturing.
///
/// Keys are FNV-1a-64 hex over `renderDigest:frameIndex` —
/// hex, so path-safe by construction. The cache is **advisory**: the digest
/// covers the render config, composition key and fluvie version, but not the
/// composition's *code*, so editing a composition under an unchanged key can
/// serve stale frames until the digest moves or a `--no-cache` run bypasses
/// it. Entries persist across [FrameCache] instances sharing the same [root].
final class FrameCache {
  /// Creates a cache rooted at [root] (created lazily on first [store]).
  FrameCache(this.root);

  /// The directory holding one file per cached frame, named by its key.
  final Directory root;

  /// The exact shape every [frameKey] produces: 16 lower-case hex characters
  /// (FNV-1a-64). [lookup] and [store] interpolate the key into a path, so
  /// they accept nothing else.
  static final RegExp _keyPattern = RegExp(r'^[0-9a-f]{16}$');

  /// The default cache root shared by the render pipeline and the capture
  /// harness: `fluvie_frame_cache` under the system temp directory.
  static Directory defaultRoot() => Directory('${Directory.systemTemp.path}/fluvie_frame_cache');

  /// The cache key of frame [frameIndex] within the render identified by
  /// [renderDigest].
  String frameKey(String renderDigest, int frameIndex) =>
      fnv1a64Hex(utf8.encode('$renderDigest:$frameIndex'));

  /// The cached frame bytes for [key], or `null` on a miss.
  ///
  /// Throws an [ArgumentError] when [key] is not 16 lower-case hex characters
  /// (the shape [frameKey] produces).
  Future<Uint8List?> lookup(String key) async {
    _checkKey(key);
    final file = File('${root.path}/$key');
    if (!file.existsSync()) return null;
    return file.readAsBytes();
  }

  /// Stores [bytes] under [key], creating [root] when needed.
  ///
  /// Throws an [ArgumentError] when [key] is not 16 lower-case hex characters
  /// (the shape [frameKey] produces).
  Future<void> store(String key, Uint8List bytes) async {
    _checkKey(key);
    await root.create(recursive: true);
    await File('${root.path}/$key').writeAsBytes(bytes, flush: true);
  }

  static void _checkKey(String key) {
    if (!_keyPattern.hasMatch(key)) {
      throw ArgumentError.value(
        key,
        'key',
        'must be 16 lower-case hex characters as produced by frameKey',
      );
    }
  }
}

/// Adapts a disk [FrameCache] to the `dart:io`-free [FrameStore] the capture
/// loop reads, computing each key from the render digest and frame index.
final class FrameCacheStore implements FrameStore {
  /// Wraps a disk [FrameCache].
  const FrameCacheStore(this._cache);

  final FrameCache _cache;

  @override
  Future<Uint8List?> lookup(String digest, int frameIndex) =>
      _cache.lookup(_cache.frameKey(digest, frameIndex));

  @override
  Future<void> store(String digest, int frameIndex, Uint8List bytes) =>
      _cache.store(_cache.frameKey(digest, frameIndex), bytes);
}

/// The frame cache used by the render pipeline; defaults to the shared
/// `fluvie_frame_cache` directory under the system temp directory and is
/// overridable (for example with a per-test root).
final frameCacheProvider = Provider<FrameCache>((ref) => FrameCache(FrameCache.defaultRoot()));
