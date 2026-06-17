import 'package:meta/meta.dart';

/// How the download endpoint should serve an object.
enum DownloadMode {
  /// The server streams the bytes itself (local files, private or public).
  stream,

  /// The client is redirected to [DownloadGrant.url] (a public or presigned URL).
  redirect,
}

/// What a `FileStore` hands back for a download request: either a URL to
/// redirect to, or an instruction to stream the bytes.
@immutable
final class DownloadGrant {
  /// Creates a grant that streams the object's bytes from the server.
  const DownloadGrant.stream() : mode = DownloadMode.stream, url = null, expiresAt = null;

  /// Creates a grant that redirects the client to [url] (valid until
  /// [expiresAt] for a presigned URL, `null` for a stable public URL).
  const DownloadGrant.redirect(this.url, {this.expiresAt}) : mode = DownloadMode.redirect;

  /// Whether to stream or redirect.
  final DownloadMode mode;

  /// The URL to redirect to, when [mode] is [DownloadMode.redirect].
  final Uri? url;

  /// When a redirect URL expires (UTC), or `null` for a stable URL / a stream.
  final DateTime? expiresAt;
}
