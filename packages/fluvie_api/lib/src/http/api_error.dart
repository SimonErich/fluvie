import 'dart:convert';

import 'package:shelf/shelf.dart';

/// A client-facing error with an HTTP status, a stable [code], and a safe
/// [message]. Handlers throw these; the error middleware turns them into JSON.
final class ApiError implements Exception {
  /// Creates an error with [statusCode], machine [code], and human [message].
  const ApiError(this.statusCode, this.code, this.message);

  /// 400 — the request body or parameters were invalid.
  const ApiError.badRequest(this.message) : statusCode = 400, code = 'invalid_request';

  /// 401 — a missing or wrong bearer token.
  const ApiError.unauthorized([this.message = 'Unauthorized'])
    : statusCode = 401,
      code = 'unauthorized';

  /// 404 — no such job or file.
  const ApiError.notFound([this.message = 'Not found']) : statusCode = 404, code = 'not_found';

  /// 410 — the resource existed but has expired.
  const ApiError.gone([this.message = 'Gone']) : statusCode = 410, code = 'gone';

  /// 413 — the request body was too large.
  const ApiError.payloadTooLarge([this.message = 'Request body too large'])
    : statusCode = 413,
      code = 'payload_too_large';

  /// 503 — a dependency (the AI provider) is not configured.
  const ApiError.unavailable(this.message) : statusCode = 503, code = 'unavailable';

  /// The HTTP status code.
  final int statusCode;

  /// A stable machine-readable code (e.g. `invalid_request`).
  final String code;

  /// A human-readable, secret-free message.
  final String message;

  /// The error as a JSON [Response].
  Response toResponse() => Response(
    statusCode,
    body: jsonEncode({
      'error': {'code': code, 'message': message},
    }),
    headers: const {'content-type': 'application/json'},
  );

  @override
  String toString() => 'ApiError($statusCode $code): $message';
}
