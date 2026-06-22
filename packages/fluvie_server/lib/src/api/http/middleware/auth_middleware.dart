import 'package:fluvie_server/src/api/http/api_error.dart';
import 'package:shelf/shelf.dart';

/// Middleware that requires `Authorization: Bearer <expected>`, throwing
/// [ApiError.unauthorized] otherwise. The token comparison is constant-time so
/// it does not leak the secret through timing.
Middleware bearerAuth(String expected) =>
    (handler) => (request) {
      final header = request.headers['authorization'];
      if (header == null || !header.startsWith('Bearer ')) {
        throw const ApiError.unauthorized();
      }
      if (!_constantTimeEquals(header.substring(7), expected)) {
        throw const ApiError.unauthorized();
      }
      return handler(request);
    };

/// Compares [a] and [b] in time independent of where they first differ.
bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var mismatch = 0;
  for (var i = 0; i < a.length; i++) {
    mismatch |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return mismatch == 0;
}
