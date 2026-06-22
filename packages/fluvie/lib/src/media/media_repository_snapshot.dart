part of 'media_repository.dart';

/// The snapshot resolution path of [MediaRepository]: rasterize each declared
/// snapshot once through the injected [SnapshotService] and cache the decoded
/// raster by its content-hash `cacheKey`, so two sources that canonicalize to
/// the same pixels share one entry.
extension _SnapshotResolution on MediaRepository {
  /// Rasterizes every source in [sources] not already cached.
  ///
  /// A remote page must clear the network allowlist before any navigation,
  /// exactly as the media byte path gates a `NetworkSource`. The live CDP
  /// capture is stubbed, so the gate lives here, in the resolution path: a
  /// disallowed host throws the typed error before [service] is ever asked to
  /// rasterize. Mermaid and inline HTML have no host and bypass it.
  Future<void> _resolveSnapshots(
    Iterable<SnapshotSource> sources,
    SnapshotService service,
  ) async {
    for (final source in sources) {
      if (_snapshots.containsKey(source.cacheKey)) {
        continue;
      }
      if (source is UrlSnapshotSource) {
        loader.allowlist.check(source.uri);
      }
      final raster = await service.rasterize(source.request);
      _snapshots[source.cacheKey] = await decodeImageBytes('snapshot "$source"', raster.bytes);
    }
  }

  /// The decoded raster for [source], looked up by its content-hash `cacheKey`.
  ui.Image _decodedSnapshot(SnapshotSource source) {
    assertResolved('decodedSnapshotFor');
    final image = _snapshots[source.cacheKey];
    if (image == null) {
      throw FluvieRenderException(
        'MediaRepository has no decoded snapshot for "$source". Was it included '
        'in the collect pass (collectSnapshotSources) before preResolveSnapshots?',
      );
    }
    return image;
  }
}
