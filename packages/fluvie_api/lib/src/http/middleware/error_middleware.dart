import 'package:fluvie_api/src/http/api_error.dart';
import 'package:shelf/shelf.dart';

/// Middleware that turns a thrown [ApiError] into its JSON response and any
/// other thrown error into a generic 500 (never leaking a stack or secrets).
Middleware jsonErrors() =>
    (handler) => (request) async {
      try {
        return await handler(request);
      } on ApiError catch (error) {
        return error.toResponse();
      } on Object {
        return const ApiError(500, 'internal', 'Internal server error').toResponse();
      }
    };
