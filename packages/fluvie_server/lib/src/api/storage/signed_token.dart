import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Mints and verifies opaque, time-limited download tokens for private files.
///
/// A token authorizes GET of exactly one job+kind pair until its expiry. The
/// payload `jobId:kind:expiresEpochMs` is base64url-encoded and joined by a dot
/// to its base64url HMAC-SHA256 digest, so a leaked URL cannot be replayed
/// against a different file and stops working once it expires. The signing key
/// never leaves the server; only the digest travels in the URL.
final class DownloadTokenSigner {
  /// Creates a signer keyed by `secret` (UTF-8 bytes of the signing key).
  const DownloadTokenSigner(this._secret);

  final List<int> _secret;

  /// Mints a token authorizing `(jobId, kind)` until [expiresAt].
  String mint({required String jobId, required String kind, required DateTime expiresAt}) {
    final payload = '$jobId:$kind:${expiresAt.toUtc().millisecondsSinceEpoch}';
    return '${_encode(payload)}.${_sign(payload)}';
  }

  /// Verifies [token] against [now], returning the granted `(jobId, kind)` or
  /// `null` when the token is malformed, tampered with, or expired.
  ({String jobId, String kind})? verify(String token, {required DateTime now}) {
    final dot = token.indexOf('.');
    if (dot <= 0 || dot == token.length - 1) return null;
    final String payload;
    try {
      payload = utf8.decode(base64Url.decode(token.substring(0, dot)));
    } on FormatException {
      return null;
    }
    if (_sign(payload) != token.substring(dot + 1)) return null;
    final parts = payload.split(':');
    if (parts.length != 3) return null;
    final expiresMs = int.tryParse(parts[2]);
    if (expiresMs == null) return null;
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresMs, isUtc: true);
    if (!now.toUtc().isBefore(expiresAt)) return null;
    return (jobId: parts[0], kind: parts[1]);
  }

  String _encode(String value) => base64Url.encode(utf8.encode(value));

  String _sign(String payload) =>
      base64Url.encode(Hmac(sha256, _secret).convert(utf8.encode(payload)).bytes);
}
