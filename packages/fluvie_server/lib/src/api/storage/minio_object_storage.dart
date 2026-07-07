// coverage:ignore-file thin minio network adapter that needs a live S3 bucket,
// so it is not exercised by the unit suite. The mapping logic it feeds
// (S3FileStore) is fully unit-tested through the S3ObjectStorage fake.
import 'dart:typed_data';

import 'package:fluvie_server/src/api/storage/s3_object_storage.dart';
import 'package:minio/minio.dart' as minio;

/// The real [S3ObjectStorage] over a `minio` client and a single bucket.
final class MinioObjectStorage implements S3ObjectStorage {
  /// Creates the adapter for [bucket] on [client].
  const MinioObjectStorage(this.client, this.bucket);

  /// The configured minio client (custom endpoint, region, path-style).
  final minio.Minio client;

  /// The bucket every object lives in.
  final String bucket;

  @override
  Future<void> putObject(
    String key,
    Stream<List<int>> data, {
    required int length,
    required Map<String, String> metadata,
  }) async {
    await client.putObject(
      bucket,
      key,
      data.map((chunk) => chunk is Uint8List ? chunk : Uint8List.fromList(chunk)),
      size: length,
      metadata: metadata,
    );
  }

  @override
  Future<S3ObjectStat?> statObject(String key) async {
    try {
      final stat = await client.statObject(bucket, key);
      return S3ObjectStat(
        size: stat.size ?? 0,
        lastModified: (stat.lastModified ?? DateTime.fromMillisecondsSinceEpoch(0)).toUtc(),
        metadata: {
          for (final entry in (stat.metaData ?? const {}).entries)
            if (entry.value != null) entry.key.toLowerCase(): entry.value!,
        },
      );
    } on minio.MinioError {
      return null;
    }
  }

  @override
  Future<Stream<List<int>>> getObject(String key) => client.getObject(bucket, key);

  @override
  Future<void> removeObject(String key) => client.removeObject(bucket, key);

  @override
  Stream<S3ObjectEntry> listObjects({String? prefix}) async* {
    final results = client.listObjects(bucket, prefix: prefix ?? '', recursive: true);
    await for (final result in results) {
      for (final object in result.objects) {
        yield S3ObjectEntry(
          key: object.key!,
          size: object.size ?? 0,
          lastModified: (object.lastModified ?? DateTime.fromMillisecondsSinceEpoch(0)).toUtc(),
        );
      }
    }
  }

  @override
  Future<Uri> presignedGetUrl(String key, {required Duration expires}) async =>
      Uri.parse(await client.presignedGetObject(bucket, key, expires: expires.inSeconds));
}
