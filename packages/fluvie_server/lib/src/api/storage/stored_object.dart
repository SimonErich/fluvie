import 'package:meta/meta.dart';

/// Whether a stored file is openly downloadable or needs a signed/bearer grant.
enum StoreVisibility {
  /// Anyone with the URL can download the object.
  public,

  /// The object needs a time-limited signed URL (or the API bearer) to download.
  private,
}

/// Metadata for one stored object, independent of the storage backend.
///
/// Both `LocalFileStore` (via a `.meta.json` sidecar) and `S3FileStore` (via
/// `x-amz-meta-*`) materialize this so retention and the download endpoint read
/// age, visibility, and content type the same way.
@immutable
final class StoredObject {
  /// Creates object metadata.
  const StoredObject({
    required this.key,
    required this.bytes,
    required this.contentType,
    required this.createdAt,
    required this.visibility,
    this.expiresAt,
  });

  /// The storage key, for example `rnd_01hx/video.mp4`.
  final String key;

  /// The object's size in bytes.
  final int bytes;

  /// The MIME type, for example `video/mp4` or `image/png`.
  final String contentType;

  /// When the object was written (UTC).
  final DateTime createdAt;

  /// Whether the object is public or private.
  final StoreVisibility visibility;

  /// When the object should be considered expired (UTC), or `null` for no TTL.
  final DateTime? expiresAt;

  /// Whether [now] is at or past [expiresAt] (always `false` without a TTL).
  bool isExpiredAt(DateTime now) => expiresAt != null && !now.isBefore(expiresAt!);
}
