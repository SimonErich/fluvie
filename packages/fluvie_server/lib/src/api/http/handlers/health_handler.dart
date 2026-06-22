import 'dart:convert';

import 'package:fluvie_server/src/api/storage/file_store.dart';
import 'package:shelf/shelf.dart';

/// Handles `GET /v1/healthz` (liveness) and `GET /v1/readyz` (readiness).
final class HealthHandler {
  /// Creates the handler; readiness probes [fileStore].
  const HealthHandler(this.fileStore);

  /// The file store probed by readiness.
  final FileStore fileStore;

  /// Liveness: always `200` while the process is up.
  Response live(Request request) => Response.ok(jsonEncode({'status': 'ok'}), headers: _json);

  /// Readiness: `200` when the file store responds, `503` otherwise.
  Future<Response> ready(Request request) async {
    try {
      await fileStore.stat('__readyz__');
    } on Object {
      return Response(
        503,
        body: jsonEncode({'status': 'degraded'}),
        headers: _json,
      );
    }
    return Response.ok(jsonEncode({'status': 'ok'}), headers: _json);
  }

  static const _json = {'content-type': 'application/json'};
}
