import 'dart:convert';
import 'dart:typed_data';

import 'package:ai_abstracted/src/core/ai_exception.dart';
import 'package:ai_abstracted/src/transport/http_errors.dart';
import 'package:http/http.dart' as http;

/// The bytes of a binary response together with their MIME type.
typedef BinaryResponse = ({Uint8List bytes, String mimeType});

/// GETs [uri] and returns its raw bytes plus the parsed content-type.
///
/// [headers] are sent as-is and [provider] labels any error. Non-2xx responses
/// map to the matching [AiException]; transport failures raise an
/// [AiTransientException]. The MIME type defaults to `application/octet-stream`.
Future<BinaryResponse> getBytes(
  http.Client client,
  Uri uri, {
  required String provider,
  Map<String, String> headers = const {},
}) async {
  final response = await _send(provider, () => client.get(uri, headers: headers));
  return _readBytes(response, provider);
}

/// POSTs [body] as JSON to [uri] and returns the raw response bytes.
///
/// Used by providers (such as ElevenLabs) that answer a JSON request with audio
/// bytes directly. [headers] are merged with a JSON content-type and [provider]
/// labels any error. Status and transport handling match [getBytes].
Future<BinaryResponse> postForBytes(
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
  return _readBytes(response, provider);
}

/// Runs [request], rethrowing [AiException]s and wrapping anything else.
Future<http.Response> _send(String provider, Future<http.Response> Function() request) async {
  try {
    return await request();
  } on AiException {
    rethrow;
  } on Object catch (error) {
    throw AiTransientException('Transport failure: $error', provider: provider, cause: error);
  }
}

/// Validates [response] status, then returns its bytes and MIME type.
BinaryResponse _readBytes(http.Response response, String provider) {
  final status = response.statusCode;
  if (status < 200 || status >= 300) {
    throw mapStatusToException(
      status,
      provider: provider,
      message: _errorMessage(response),
      headers: response.headers,
    );
  }
  return (bytes: response.bodyBytes, mimeType: _mimeType(response));
}

/// The content-type of [response] without parameters, defaulting to octets.
String _mimeType(http.Response response) {
  final header = response.headers['content-type'];
  if (header == null || header.trim().isEmpty) {
    return 'application/octet-stream';
  }
  return header.split(';').first.trim();
}

/// A short error message from [response], preferring its body when present.
String _errorMessage(http.Response response) {
  final body = response.body.trim();
  if (body.isEmpty) {
    return 'HTTP ${response.statusCode}';
  }
  return body.length > 500 ? body.substring(0, 500) : body;
}
