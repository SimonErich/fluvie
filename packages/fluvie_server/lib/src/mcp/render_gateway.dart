import 'package:fluvie_server/client.dart';

/// The seam the MCP tools render through.
///
/// The default implementation, `ApiRenderGateway`, talks to a running Fluvie
/// render API; a fake makes the tools testable with no network.
abstract interface class RenderGateway {
  /// Submits [request] and waits for the render to finish.
  Future<RenderJobView> render(ApiRenderRequest request);

  /// Statically validates Fluvie Dart [code] (a top-level `Video build()`
  /// snippet) without rendering it, so a model can check the format before a
  /// render. The code is never executed.
  Future<ApiValidationResult> validate(String code);

  /// Fetches the `VideoSpec` JSON Schema the model authors against.
  Future<Map<String, Object?>> fetchSpecSchema();

  /// Releases any held resources (for example HTTP connections).
  void close();
}
