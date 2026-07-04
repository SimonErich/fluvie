import 'package:fluvie_server/src/config/env_trim.dart';
import 'package:fluvie_server/src/mcp/api_render_gateway.dart';
import 'package:fluvie_server/src/mcp/render_gateway.dart';
import 'package:meta/meta.dart';

/// Configuration for the MCP server, usually read from the environment.
@immutable
final class McpServerConfig {
  /// Creates a configuration.
  const McpServerConfig({
    required this.apiBaseUrl,
    this.apiToken,
    this.mcpToken,
    this.host = '0.0.0.0',
    this.port = 8080,
  });

  /// Reads configuration from an environment map (typically
  /// `Platform.environment`).
  ///
  /// - `FLUVIE_API_URL`: the render API base URL (defaults to localhost:8080).
  /// - `FLUVIE_API_TOKEN`: the bearer token sent to the render API.
  /// - `FLUVIE_MCP_TOKEN`: the bearer token required on the HTTP MCP endpoint.
  /// - `HOST` / `PORT`: where the HTTP transport binds.
  factory McpServerConfig.fromEnv(Map<String, String> env) {
    final url = env['FLUVIE_API_URL'];
    return McpServerConfig(
      apiBaseUrl: Uri.parse(url == null || url.isEmpty ? 'http://localhost:8080' : url),
      apiToken: trimToNull(env['FLUVIE_API_TOKEN']),
      mcpToken: trimToNull(env['FLUVIE_MCP_TOKEN']),
      host: trimToNull(env['HOST']) ?? '0.0.0.0',
      port: int.tryParse(env['PORT'] ?? '') ?? 8080,
    );
  }

  /// The render API base URL.
  final Uri apiBaseUrl;

  /// The bearer token sent to the render API, or `null` for none.
  final String? apiToken;

  /// The bearer token required on the HTTP MCP endpoint, or `null` for open.
  final String? mcpToken;

  /// The host the HTTP transport binds to.
  final String host;

  /// The port the HTTP transport binds to.
  final int port;

  /// Builds the render gateway this configuration points at.
  RenderGateway buildGateway() => ApiRenderGateway(baseUrl: apiBaseUrl, apiToken: apiToken);
}
