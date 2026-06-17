import 'package:shelf/shelf.dart';

/// Middleware that adds CORS headers for [allowedOrigins].
///
/// Empty origins disables CORS (a no-op). `['*']` allows any origin; otherwise
/// only a request whose `Origin` is in the list is allowed. A preflight
/// `OPTIONS` request gets a `200` with the CORS headers.
Middleware corsHeaders(List<String> allowedOrigins) =>
    (handler) => (request) async {
      if (allowedOrigins.isEmpty) return handler(request);
      final allow = _allowFor(request.headers['origin'], allowedOrigins);
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: _headers(allow));
      }
      final response = await handler(request);
      return allow == null ? response : response.change(headers: _headers(allow));
    };

String? _allowFor(String? origin, List<String> allowed) {
  if (allowed.contains('*')) return '*';
  if (origin != null && allowed.contains(origin)) return origin;
  return null;
}

Map<String, String> _headers(String? allow) => {
  'access-control-allow-origin': ?allow,
  'access-control-allow-methods': 'GET, POST, OPTIONS',
  'access-control-allow-headers': 'authorization, content-type',
};
