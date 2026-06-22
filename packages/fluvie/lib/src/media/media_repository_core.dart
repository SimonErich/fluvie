part of 'media_repository.dart';

/// The shared internals of [MediaRepository] (the image pre-resolve pass and
/// the resolved-or-throw lookup), kept in a part so the wide `MediaResolver`
/// `@override` surface and the per-kind resolution helpers each stay within the
/// file budget. The image cache, decode, and determinism guard live in the
/// shared [ImageResolveCache] mixin. These are private helpers, not interface
/// members, so they live in an extension; the `@override` accessors in the main
/// class call them with implicit `this`.
extension _RepositoryInternals on MediaRepository {
  /// The shared lookup-or-throw every read accessor uses: asserts the pre-pass
  /// ran, returns `cache[key]`, or throws a typed error naming [what] (the
  /// missing thing) and [hint] (the pass that would have resolved it).
  V _require<K, V>(Map<K, V> cache, K key, String member, String what, String hint) {
    assertResolved(member);
    final value = cache[key];
    if (value == null) {
      throw FluvieRenderException('MediaRepository has no $what for "$key". $hint');
    }
    return value;
  }

  /// The image pre-resolve pass: load, content-hash, and decode every source
  /// not already cached. A clip source is content-hashed but not decoded as an
  /// image (the footgun guard): clips decode through `preResolveClip`, never
  /// here, so decoding video bytes as an image cannot throw mid-pass — a later
  /// `decodedImageFor` on a clip surfaces the clear "no decoded image" error.
  Future<void> _resolveAll(Iterable<MediaSource> sources) async {
    for (final source in sources) {
      if (resolved.containsKey(source)) continue;
      final media = await loadAndCacheBytes(source);
      if (!isClipSource(source)) {
        decoded[source] = await decodeImageBytes('image "$source"', media.bytes);
      }
    }
  }
}
