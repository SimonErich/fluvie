import 'dart:typed_data';

import 'package:fluvie_server/src/api/storage/download_grant.dart';
import 'package:fluvie_server/src/api/storage/file_store.dart';
import 'package:fluvie_server/src/api/storage/stored_object.dart';

/// An in-memory [FileStore] for tests: objects live in a map, downloads stream
/// the buffered bytes. No filesystem, no clock beyond the injectable `now` used
/// for `createdAt`.
final class InMemoryFileStore implements FileStore {
  /// Creates an empty store; [now] stamps each object's `createdAt`.
  InMemoryFileStore({DateTime? now}) : _now = now ?? DateTime.utc(2026);

  final DateTime _now;
  final Map<String, _Entry> _objects = {};

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
    final builder = BytesBuilder();
    await data.forEach(builder.add);
    final bytes = builder.takeBytes();
    final object = StoredObject(
      key: key,
      bytes: bytes.length,
      contentType: contentType,
      createdAt: _now,
      visibility: visibility,
      expiresAt: expiresAt,
    );
    _objects[key] = _Entry(bytes, object);
    return object;
  }

  @override
  Future<StoredObject?> stat(String key) async => _objects[key]?.object;

  @override
  Future<Stream<List<int>>> openRead(String key) async {
    final entry = _objects[key];
    if (entry == null) throw FileStoreException('No such object: $key');
    return Stream.value(entry.bytes);
  }

  @override
  Future<void> delete(String key) async => _objects.remove(key);

  @override
  Stream<StoredObject> list({String? prefix}) => Stream.fromIterable(
    // Snapshot so a caller can delete during iteration.
    _objects.values
        .map((e) => e.object)
        .where((o) => prefix == null || o.key.startsWith(prefix))
        .toList(),
  );

  @override
  Future<DownloadGrant> downloadGrant(
    String key, {
    required StoreVisibility visibility,
    required Duration ttl,
  }) async => const DownloadGrant.stream();
}

final class _Entry {
  _Entry(this.bytes, this.object);
  final Uint8List bytes;
  final StoredObject object;
}
