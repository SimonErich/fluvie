import 'dart:typed_data';

import 'package:fluvie_api/src/storage/s3_object_storage.dart';

/// In-memory `S3ObjectStorage` for unit-testing `S3FileStore` without a bucket.
final class FakeS3ObjectStorage implements S3ObjectStorage {
  /// Creates an empty fake; [now] stamps each object's `lastModified`.
  FakeS3ObjectStorage({DateTime? now}) : _now = now ?? DateTime.utc(2026);

  final DateTime _now;
  final Map<String, _Object> _objects = {};

  /// The keys currently stored, for assertions.
  Iterable<String> get keys => _objects.keys;

  @override
  Future<void> putObject(
    String key,
    Stream<List<int>> data, {
    required int length,
    required Map<String, String> metadata,
  }) async {
    final builder = BytesBuilder();
    await data.forEach(builder.add);
    _objects[key] = _Object(builder.takeBytes(), Map.of(metadata), _now);
  }

  @override
  Future<S3ObjectStat?> statObject(String key) async {
    final object = _objects[key];
    if (object == null) return null;
    return S3ObjectStat(
      size: object.bytes.length,
      lastModified: object.lastModified,
      // Lower-case keys, mirroring how a real bucket returns x-amz-meta-*.
      metadata: {for (final e in object.metadata.entries) e.key.toLowerCase(): e.value},
    );
  }

  @override
  Future<Stream<List<int>>> getObject(String key) async {
    final object = _objects[key];
    if (object == null) throw StateError('no such object: $key');
    return Stream.value(object.bytes);
  }

  @override
  Future<void> removeObject(String key) async => _objects.remove(key);

  @override
  Stream<S3ObjectEntry> listObjects({String? prefix}) => Stream.fromIterable([
    for (final entry in _objects.entries)
      if (prefix == null || entry.key.startsWith(prefix))
        S3ObjectEntry(
          key: entry.key,
          size: entry.value.bytes.length,
          lastModified: entry.value.lastModified,
        ),
  ]);

  @override
  Future<Uri> presignedGetUrl(String key, {required Duration expires}) async =>
      Uri.parse('https://s3.test/$key?expires=${expires.inSeconds}');
}

final class _Object {
  _Object(this.bytes, this.metadata, this.lastModified);
  final Uint8List bytes;
  final Map<String, String> metadata;
  final DateTime lastModified;
}
