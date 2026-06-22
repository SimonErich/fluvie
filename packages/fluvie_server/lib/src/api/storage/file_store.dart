import 'package:fluvie_server/src/api/storage/download_grant.dart';
import 'package:fluvie_server/src/api/storage/stored_object.dart';

/// Stores rendered artifacts (the video and its poster) and serves them back.
///
/// One contract over two backends: `LocalFileStore` (the filesystem) and
/// `S3FileStore` (any S3-compatible bucket). Keys are server-generated
/// `<jobId>/<kind>.<ext>` strings; everything streams so a large MP4 never sits
/// in memory. Implementations make [delete] idempotent.
abstract interface class FileStore {
  /// Writes [data] at [key] with [contentType] and [visibility], optionally
  /// tagging it with [expiresAt] (used by retention) and [length] (the byte
  /// count, when known up front). Returns the stored object's metadata.
  Future<StoredObject> put(
    String key,
    Stream<List<int>> data, {
    required String contentType,
    required StoreVisibility visibility,
    int? length,
    DateTime? expiresAt,
  });

  /// Metadata for [key], or `null` when no such object exists.
  Future<StoredObject?> stat(String key);

  /// Streams the bytes of [key]; throws [FileStoreException] when absent.
  Future<Stream<List<int>>> openRead(String key);

  /// Deletes [key]. A no-op when the object is already gone (idempotent).
  Future<void> delete(String key);

  /// Every stored object (optionally under [prefix]) with its metadata, for
  /// retention sweeps.
  Stream<StoredObject> list({String? prefix});

  /// How the download endpoint should serve [key] given its [visibility]: a
  /// stream (local files) or a redirect to a public/presigned URL (S3), valid
  /// for [ttl] when time-limited.
  Future<DownloadGrant> downloadGrant(
    String key, {
    required StoreVisibility visibility,
    required Duration ttl,
  });
}

/// Thrown when a [FileStore] operation fails (a missing object on read, an IO
/// error, a backend error).
final class FileStoreException implements Exception {
  /// Creates the exception with a human-readable [message].
  const FileStoreException(this.message);

  /// What went wrong, safe to log (never includes secrets).
  final String message;

  @override
  String toString() => 'FileStoreException: $message';
}

/// Whether [key] is a safe relative storage key: one or more
/// `[A-Za-z0-9._-]` segments joined by single `/`, with no empty segment, no
/// `..`, and no leading/trailing slash. Rejects anything that could escape the
/// storage root.
bool isSafeStorageKey(String key) {
  if (key.isEmpty || key.startsWith('/') || key.endsWith('/')) return false;
  return key.split('/').every((s) => s.isNotEmpty && s != '..' && _segment.hasMatch(s));
}

final RegExp _segment = RegExp(r'^[A-Za-z0-9._-]+$');
