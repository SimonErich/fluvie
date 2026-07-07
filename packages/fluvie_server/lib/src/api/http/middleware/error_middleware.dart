import 'dart:io';

import 'package:fluvie_server/src/api/http/api_error.dart';
import 'package:shelf/shelf.dart';

/// Middleware that turns a thrown [ApiError] into its JSON response and any
/// other thrown error into a generic 500 (never leaking a stack or secrets).
Middleware jsonErrors() =>
    (handler) => (request) async {
      try {
        return await handler(request);
      } on ApiError catch (error) {
        return error.toResponse();
      } on Object catch (error, stackTrace) {
        // The 500 body stays generic (no stack or secrets), but the operator
        // needs the cause: log it to stderr before returning the opaque error.
        stderr.writeln(
          'fluvie_server: unhandled error on ${request.method} ${request.requestedUri.path}: '
          '$error\n$stackTrace',
        );
        return const ApiError(500, 'internal', 'Internal server error').toResponse();
      }
    };
