import 'dart:convert';

import 'package:fluvie_server/src/api/http/api_error.dart';
import 'package:shelf/shelf.dart';

/// Reads and decodes a JSON object from [request], capped at [maxBytes].
///
/// Throws [ApiError.payloadTooLarge] (413) when the body exceeds the cap and
/// [ApiError.badRequest] (400) when it is not a JSON object. An empty body
/// decodes to an empty map (so optional-body endpoints work).
Future<Map<String, Object?>> readJsonObject(Request request, {int maxBytes = 1 << 20}) async {
  final bytes = <int>[];
  await for (final chunk in request.read()) {
    bytes.addAll(chunk);
    if (bytes.length > maxBytes) throw const ApiError.payloadTooLarge();
  }
  if (bytes.isEmpty) return {};
  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(bytes));
  } on FormatException {
    throw const ApiError.badRequest('Body must be valid JSON');
  }
  if (decoded is! Map<String, Object?>) {
    throw const ApiError.badRequest('Body must be a JSON object');
  }
  return decoded;
}
