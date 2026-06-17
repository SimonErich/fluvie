import 'package:meta/meta.dart';

/// A narrow seam over the handful of S3 operations `S3FileStore` needs.
///
/// Wrapping the `minio` client behind this interface keeps the store's mapping
/// logic (keys, metadata, visibility, presign TTLs) fully unit-testable against
/// a fake, while the real network calls live in `MinioObjectStorage` (which is
/// integration-tested, not unit-tested).
abstract interface class S3ObjectStorage {
  /// Uploads [data] ([length] bytes) at [key] with the given user [metadata]
  /// (including a `content-type`).
  Future<void> putObject(
    String key,
    Stream<List<int>> data, {
    required int length,
    required Map<String, String> metadata,
  });

  /// HEADs [key], returning its stat or `null` when it does not exist.
  Future<S3ObjectStat?> statObject(String key);

  /// Streams the bytes of [key] (the caller has checked it exists).
  Future<Stream<List<int>>> getObject(String key);

  /// Removes [key] (idempotent — a missing object is not an error).
  Future<void> removeObject(String key);

  /// Lists objects, optionally under [prefix].
  Stream<S3ObjectEntry> listObjects({String? prefix});

  /// A presigned GET URL for [key], valid for [expires].
  Future<Uri> presignedGetUrl(String key, {required Duration expires});
}

/// The result of a HEAD: size, last-modified time, and user metadata.
@immutable
final class S3ObjectStat {
  /// Creates a stat result.
  const S3ObjectStat({required this.size, required this.lastModified, required this.metadata});

  /// Object size in bytes.
  final int size;

  /// When the object was last modified (UTC).
  final DateTime lastModified;

  /// User metadata (the `x-amz-meta-*` values), keys lower-cased.
  final Map<String, String> metadata;
}

/// One entry from a bucket listing.
@immutable
final class S3ObjectEntry {
  /// Creates a listing entry.
  const S3ObjectEntry({required this.key, required this.size, required this.lastModified});

  /// The object key.
  final String key;

  /// Object size in bytes.
  final int size;

  /// When the object was last modified (UTC).
  final DateTime lastModified;
}
