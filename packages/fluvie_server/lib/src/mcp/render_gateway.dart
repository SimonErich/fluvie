import 'package:fluvie_server/client.dart';

/// The seam the MCP tools render through.
///
/// The default implementation, `ApiRenderGateway`, talks to a running Fluvie
/// render API; a fake makes the tools testable with no network.
abstract interface class RenderGateway {
  /// Submits [request] and waits for the render to finish.
  Future<RenderJobView> render(ApiRenderRequest request);

  /// Fetches the `VideoSpec` JSON Schema the model authors against.
  Future<Map<String, Object?>> fetchSpecSchema();

  /// Releases any held resources (for example HTTP connections).
  void close();
}
