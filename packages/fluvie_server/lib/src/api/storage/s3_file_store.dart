import 'package:fluvie_server/src/api/storage/download_grant.dart';
import 'package:fluvie_server/src/api/storage/file_store.dart';
import 'package:fluvie_server/src/api/storage/s3_object_storage.dart';
import 'package:fluvie_server/src/api/storage/stored_object.dart';

/// A [FileStore] backed by an S3-compatible bucket through the [S3ObjectStorage]
/// seam.
///
/// Visibility, expiry, and content type ride along as object metadata. A public
/// object resolves to a stable URL under [publicBaseUrl] (or streams through the
/// server when none is set); a private object resolves to a freshly minted
/// presigned GET URL, so a download link is never stale.
final class S3FileStore implements FileStore {
  /// Creates a store over `storage`; public objects use [publicBaseUrl] when set.
  S3FileStore(this._storage, {this.publicBaseUrl});

  final S3ObjectStorage _storage;

  /// Base URL for public objects (e.g. a CDN); `null` streams them through.
  final Uri? publicBaseUrl;

  static const _visibilityKey = 'visibility';
  static const _contentTypeKey = 'contenttype';
  static const _expiresKey = 'expiresatms';

  @override
  Future<StoredObject> put(
    String key,
    Stream<List<int>> data, {
    required String contentType,
    required StoreVisibility visibility,
    int? length,
    DateTime? expiresAt,
  }) async {
    if (!isSafeStorageKey(key)) throw FileStoreException('Unsafe storage key: $key');
    if (length == null) throw const FileStoreException('S3 uploads need a known length');
    await _storage.putObject(
      key,
      data,
      length: length,
      metadata: {
        'content-type': contentType,
        _contentTypeKey: contentType,
        _visibilityKey: visibility.name,
        if (expiresAt != null) _expiresKey: '${expiresAt.toUtc().millisecondsSinceEpoch}',
      },
    );
    final stat = await _storage.statObject(key);
    if (stat == null) throw FileStoreException('Upload of $key did not persist');
    return _toStored(key, stat);
  }

  @override
  Future<StoredObject?> stat(String key) async {
    final stat = await _storage.statObject(key);
    return stat == null ? null : _toStored(key, stat);
  }

  @override
  Future<Stream<List<int>>> openRead(String key) async {
    if (await _storage.statObject(key) == null) {
      throw FileStoreException('No such object: $key');
    }
    return _storage.getObject(key);
  }

  @override
  Future<void> delete(String key) => _storage.removeObject(key);

  @override
  Stream<StoredObject> list({String? prefix}) async* {
    await for (final entry in _storage.listObjects(prefix: prefix)) {
      final stat = await _storage.statObject(entry.key);
      if (stat != null) yield _toStored(entry.key, stat);
    }
  }

  @override
  Future<DownloadGrant> downloadGrant(
    String key, {
    required StoreVisibility visibility,
    required Duration ttl,
  }) async {
    if (visibility == StoreVisibility.public) {
      final base = publicBaseUrl;
      if (base == null) return const DownloadGrant.stream();
      return DownloadGrant.redirect(base.resolve(key));
    }
    return DownloadGrant.redirect(await _storage.presignedGetUrl(key, expires: ttl));
  }

  StoredObject _toStored(String key, S3ObjectStat stat) {
    final meta = stat.metadata;
    final expiresMs = int.tryParse(meta[_expiresKey] ?? '');
    return StoredObject(
      key: key,
      bytes: stat.size,
      contentType: meta[_contentTypeKey] ?? 'application/octet-stream',
      createdAt: stat.lastModified.toUtc(),
      visibility: meta[_visibilityKey] == 'public'
          ? StoreVisibility.public
          : StoreVisibility.private,
      expiresAt: expiresMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expiresMs, isUtc: true),
    );
  }
}
