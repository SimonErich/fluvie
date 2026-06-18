import 'dart:convert';

import 'package:fluvie_ai/src/client/ai_client.dart';
import 'package:http/http.dart' as http;

/// POSTs [body] as JSON to [uri] with [headers] and returns the decoded JSON
/// object.
///
/// [provider] names the backend in error messages. Throws an [AiClientException]
/// on a transport error, a non-2xx status, invalid JSON, or a non-object body.
Future<Map<String, Object?>> postJson(
  http.Client client,
  Uri uri,
  Map<String, String> headers,
  Map<String, Object?> body, {
  required String provider,
}) async {
  final http.Response response;
  try {
    response = await client.post(
      uri,
      headers: {'content-type': 'application/json', ...headers},
      body: jsonEncode(body),
    );
  } on Object catch (error) {
    throw AiClientException('$provider request failed: $error');
  }
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw AiClientException('$provider returned HTTP ${response.statusCode}: ${response.body}');
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(response.body);
  } on FormatException catch (error) {
    throw AiClientException('$provider returned invalid JSON: ${error.message}');
  }
  if (decoded is! Map<String, Object?>) {
    throw AiClientException('$provider returned a non-object response');
  }
  return decoded;
}
