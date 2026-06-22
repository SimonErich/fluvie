import 'package:shelf/shelf.dart';

/// Handles `GET /v1/schema/video-spec`: serve the committed `VideoSpec` JSON
/// schema so an editor can validate specs client-side.
final class SchemaHandler {
  /// Creates the handler over the schema [json] (the asset's contents).
  const SchemaHandler(this.json);

  /// The JSON schema document, verbatim.
  final String json;

  /// Serves the schema with a cacheable response.
  Response get(Request request) => Response.ok(
    json,
    headers: const {'content-type': 'application/json', 'cache-control': 'public, max-age=3600'},
  );
}
