import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/hash/fnv1a.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/media/media_bytes_loader.dart';

/// The shared image cache behind every [MediaResolver]: load + content-hash +
/// decode a source once before the frame loop, then serve it synchronously.
///
/// It owns only the platform-agnostic image path (bytes in, `ui.Image` out)
/// over the injected [loader], so both the `dart:io`-backed `MediaRepository`
/// and the browser `WebImageMediaResolver` reuse it without duplicating the
/// decode, cache, or determinism guard. Per-kind caches (clips, audio,
/// snapshots, captions) stay with each implementation.
mixin ImageResolveCache {
  /// The per-kind byte source resolved sources are read through.
  MediaBytesLoader get loader;

  /// The pre-resolved bytes and content hash for each source.
  final Map<MediaSource, ResolvedMedia> resolved = {};

  /// The pre-decoded image for each non-clip source.
  final Map<MediaSource, ui.Image> decoded = {};

  bool _preResolved = false;

  /// Records that the pre-resolve pass has completed, unlocking the synchronous
  /// read accessors.
  void markResolved() => _preResolved = true;

  /// Guards every read accessor: the pre-resolve pass must complete before the
  /// frame loop reads media (no async media mid-frame, the determinism rule).
  void assertResolved(String member) {
    if (!_preResolved) {
      throw StateError(
        '$member was called before preResolveAll completed. The pre-resolve '
        'pass must run before the frame loop (no async media mid-frame).',
      );
    }
  }

  /// Loads and content-hashes [source], caching the result in [resolved] and
  /// returning it. Callers guard against re-resolving an already-cached source
  /// (so the per-source load and decode each run once).
  Future<ResolvedMedia> loadAndCacheBytes(MediaSource source) async {
    final bytes = await loader.load(source);
    return resolved[source] = (bytes: bytes, contentHash: fnv1a64Hex(bytes));
  }

  /// Decodes [bytes] to a single `ui.Image`, wrapping any failure in a typed
  /// [FluvieRenderException] naming the [label]. Shared by the image and
  /// snapshot paths.
  Future<ui.Image> decodeImageBytes(String label, Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } on Object catch (error) {
      throw FluvieRenderException('Failed to decode $label: $error.');
    }
  }

  /// Disposes every decoded image and clears the caches, freeing native memory
  /// instead of waiting for garbage collection. Idempotent: a second call has
  /// nothing left to dispose.
  void disposeCachedImages() {
    for (final image in decoded.values) {
      image.dispose();
    }
    decoded.clear();
    resolved.clear();
  }
}
