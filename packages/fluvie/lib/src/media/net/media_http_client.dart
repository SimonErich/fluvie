import 'dart:typed_data';

import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod/riverpod.dart';

/// The single network seam for media fetches.
///
/// Everything that downloads media goes through this contract, so tests inject
/// a fake (or a canned `http.Client`) and never touch the live network. The
/// allowlist check happens *before* [MediaHttpClient.get] is called (in the
/// byte loader), so a client may assume its URL is already permitted.
// ignore: one_member_abstracts — new-service seam; mockable where a bare function isn't.
abstract interface class MediaHttpClient {
  /// Fetches [url] and completes with its body bytes.
  ///
  /// A non-2xx response or a transport failure is a [FluvieRenderException].
  Future<Uint8List> get(Uri url);
}

/// The real [MediaHttpClient]: a thin wrapper over an `http.Client`.
final class HttpMediaHttpClient implements MediaHttpClient {
  /// Creates the client over [_inner] (defaults to a fresh `http.Client`).
  HttpMediaHttpClient([http.Client? inner]) : _inner = inner ?? http.Client();

  final http.Client _inner;

  @override
  Future<Uint8List> get(Uri url) async {
    final http.Response response;
    try {
      response = await _inner.get(url);
    } on Object catch (error) {
      throw FluvieRenderException('Network fetch of "$url" failed: $error.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FluvieRenderException(
        'Network fetch of "$url" returned HTTP ${response.statusCode}.',
      );
    }
    return response.bodyBytes;
  }
}

/// The media HTTP client used by the byte loader; defaults to a real
/// [HttpMediaHttpClient] and is overridable with a fake in tests.
final mediaHttpClientProvider = Provider<MediaHttpClient>((ref) => HttpMediaHttpClient());
