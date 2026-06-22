import 'dart:convert';

import 'package:fluvie_server/src/api/cleanup/retention_service.dart';
import 'package:fluvie_server/src/api/http/api_error.dart';
import 'package:fluvie_server/src/api/http/json_body.dart';
import 'package:shelf/shelf.dart';

/// Handles `POST /v1/maintenance/cleanup`: run a retention sweep. The body may
/// carry `{"dryRun": true}` to report without deleting.
final class MaintenanceHandler {
  /// Creates the handler over [retention].
  const MaintenanceHandler(this.retention);

  /// The retention service that performs the sweep.
  final RetentionService retention;

  /// Runs (or dry-runs) a cleanup sweep and returns its report.
  Future<Response> cleanup(Request request) async {
    final body = await readJsonObject(request);
    final dryRun = body['dryRun'];
    if (dryRun != null && dryRun is! bool) {
      throw const ApiError.badRequest('dryRun must be a boolean');
    }
    final report = await retention.sweep(dryRun: (dryRun as bool?) ?? false);
    return Response.ok(
      jsonEncode(report.toJson()),
      headers: const {'content-type': 'application/json'},
    );
  }
}
