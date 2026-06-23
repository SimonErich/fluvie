import 'dart:io';

import 'package:shelf/shelf.dart';

/// The sentinel returned when no client address can be determined, so a
/// rate-limiter key is always non-empty.
const String unknownClientIp = 'unknown';

/// Resolves the client IP for rate limiting from a shelf [request].
///
/// The public server runs behind a proxy, so the real client is the first hop
/// in `x-forwarded-for` (`client, proxy1, proxy2`). When that header is absent
/// or blank, it falls back to the socket's remote address from the shelf
/// connection info; if neither is available it returns [unknownClientIp].
///
/// Only the first hop is trusted: later hops are attacker-controllable, and the
/// edge proxy is responsible for stripping any client-supplied header.
String clientIp(Request request) {
  final forwarded = request.headers['x-forwarded-for'];
  if (forwarded != null) {
    final firstHop = forwarded.split(',').first.trim();
    if (firstHop.isNotEmpty) return firstHop;
  }
  final info = request.context['shelf.io.connection_info'];
  if (info is HttpConnectionInfo) return info.remoteAddress.address;
  return unknownClientIp;
}
