part of 'media_repository.dart';

/// The shared internals of [MediaRepository] (decode + the resolved-or-throw
/// lookup), kept in a part so the wide `MediaResolver` `@override` surface and
/// the per-kind resolution helpers each stay within the file budget. These are
/// private helpers, not interface members, so they live in an extension; the
/// `@override` accessors in the main class call them with implicit `this`.
extension _RepositoryInternals on MediaRepository {
  /// The shared lookup-or-throw every read accessor uses: asserts the pre-pass
  /// ran, returns `cache[key]`, or throws a typed error naming [what] (the
  /// missing thing) and [hint] (the pass that would have resolved it).
  V _require<K, V>(Map<K, V> cache, K key, String member, String what, String hint) {
    _assertResolved(member);
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
      if (_resolved.containsKey(source)) continue;
      final bytes = await loader.load(source);
      _resolved[source] = (bytes: bytes, contentHash: fnv1a64Hex(bytes));
      if (!_isClipSource(source)) {
        _decoded[source] = await _decode(source, bytes);
      }
    }
  }

  /// Decodes image [bytes] for [source] to a `ui.Image` (the image-cache path).
  Future<ui.Image> _decode(MediaSource source, Uint8List bytes) =>
      _decodeBytes('image "$source"', bytes);

  /// Decodes [bytes] to a single `ui.Image`, wrapping any failure in a typed
  /// [FluvieRenderException] naming the [label]. Shared by the image and
  /// snapshot paths.
  Future<ui.Image> _decodeBytes(String label, Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } on Object catch (error) {
      throw FluvieRenderException('Failed to decode $label: $error.');
    }
  }

  /// Guards every read accessor: the pre-resolve pass must complete before the
  /// frame loop reads media (no async media mid-frame, the determinism rule).
  void _assertResolved(String member) {
    if (!_preResolved) {
      throw StateError(
        '$member was called before preResolveAll completed. The pre-resolve '
        'pass must run before the frame loop (no async media mid-frame).',
      );
    }
  }
}
