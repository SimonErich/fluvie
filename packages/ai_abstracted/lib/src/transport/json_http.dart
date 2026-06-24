import 'dart:convert';

import 'package:ai_abstracted/src/core/ai_exception.dart';
import 'package:ai_abstracted/src/transport/http_errors.dart';
import 'package:http/http.dart' as http;

/// POSTs [body] as JSON to [uri] and returns the decoded JSON object.
///
/// [headers] are merged with a JSON content-type, [provider] labels any error,
/// and the response must be a 2xx carrying a JSON object. Non-2xx responses map
/// to the matching [AiException]; a non-object or malformed body raises an
/// [AiResponseException]; transport failures raise an [AiTransientException].
Future<Map<String, Object?>> postJson(
  http.Client client,
  Uri uri, {
  required Map<String, String> headers,
  required Object body,
  required String provider,
}) async {
  final response = await _send(
    provider,
    () => client.post(
      uri,
      headers: {'content-type': 'application/json', ...headers},
      body: jsonEncode(body),
    ),
  );
  return _decodeObject(response, provider);
}

/// GETs [uri] and returns the decoded JSON object.
///
/// Behaves like [postJson] for status and body handling; [headers] are sent
/// as-is and [provider] labels any error.
Future<Map<String, Object?>> getJson(
  http.Client client,
  Uri uri, {
  required Map<String, String> headers,
  required String provider,
}) async {
  final response = await _send(provider, () => client.get(uri, headers: headers));
  return _decodeObject(response, provider);
}

/// Runs [request], rethrowing [AiException]s and wrapping anything else.
Future<http.Response> _send(String provider, Future<http.Response> Function() request) async {
  try {
    return await request();
  } on AiException {
    rethrow;
  } on Object catch (error) {
    throw AiTransientException(
      'Transport failure: $error',
      provider: provider,
      cause: error,
    );
  }
}

/// Validates [response] status, then decodes its body as a JSON object.
Map<String, Object?> _decodeObject(http.Response response, String provider) {
  final status = response.statusCode;
  if (status < 200 || status >= 300) {
    throw mapStatusToException(
      status,
      provider: provider,
      message: _errorMessage(response),
      headers: response.headers,
    );
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(response.body);
  } on FormatException catch (error) {
    throw AiResponseException(
      'Response was not valid JSON',
      provider: provider,
      statusCode: status,
      cause: error,
    );
  }
  if (decoded is! Map<String, Object?>) {
    throw AiResponseException(
      'Expected a JSON object but got ${decoded.runtimeType}',
      provider: provider,
      statusCode: status,
    );
  }
  return decoded;
}

/// A short error message from [response], preferring its body when present.
String _errorMessage(http.Response response) {
  final body = response.body.trim();
  if (body.isEmpty) {
    return 'HTTP ${response.statusCode}';
  }
  return body.length > 500 ? body.substring(0, 500) : body;
}
