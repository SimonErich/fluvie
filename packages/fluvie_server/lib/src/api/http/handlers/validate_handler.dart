import 'dart:convert';

import 'package:fluvie_server/src/api/http/api_error.dart';
import 'package:fluvie_server/src/api/http/json_body.dart';
import 'package:fluvie_server/src/api/validate/code_validation_service.dart';
import 'package:shelf/shelf.dart';

/// Handles `POST /v1/validate`: statically analyze a submitted code snippet and
/// return its diagnostics. The snippet is never executed.
final class ValidateHandler {
  /// Creates the handler, capping the request body at [maxCodeBytes].
  const ValidateHandler({required this.validator, this.maxCodeBytes = 64 * 1024});

  /// The analyzer the snippet is handed to.
  final CodeValidationService validator;

  /// The largest accepted request body, in bytes.
  final int maxCodeBytes;

  /// Validates the `code` in the request body, returning `200` with the result.
  Future<Response> validate(Request request) async {
    final body = await readJsonObject(request, maxBytes: maxCodeBytes);
    final code = body['code'];
    if (code is! String || code.trim().isEmpty) {
      throw const ApiError.badRequest('code must be a non-empty string');
    }
    final result = await validator.validate(code);
    return Response.ok(
      jsonEncode(result.toJson()),
      headers: const {'content-type': 'application/json'},
    );
  }
}
