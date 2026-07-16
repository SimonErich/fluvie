import 'dart:io';

import 'package:fluvie_server/src/api/http/server_dependencies.dart';
import 'package:fluvie_server/src/app/server_tools.dart';
import 'package:fluvie_server/src/config/fluvie_server_config.dart';
import 'package:fluvie_server/src/config/mcp_mode.dart';
import 'package:fluvie_server/src/docs/doc_repository.dart';
import 'package:fluvie_server/src/docs/doc_search_service.dart';
import 'package:fluvie_server/src/mcp/api_render_gateway.dart';
import 'package:fluvie_server/src/mcp/local_render_gateway.dart';
import 'package:fluvie_server/src/mcp/mcp_server.dart';
import 'package:fluvie_server/src/mcp/render_gateway.dart';

/// The MCP server name and version advertised in `initialize`.
/// `tool/set_version.sh` rewrites the version on release, in lockstep with the
/// pubspec (a test guards the two staying equal).
const String _name = 'fluvie';
const String _version = '0.3.0';

/// Loads the documentation corpus when docs are enabled, else `null`.
DocSearchService? buildDocs(FluvieServerConfig config) => config.enableDocs
    ? DocSearchService.fromRepository(FileDocRepository(Directory(config.docsDir)))
    : null;

/// Selects the render gateway for MCP build mode: the in-process [api] when it
/// runs here, otherwise a remote one at `FLUVIE_API_URL`. Returns `null` when MCP
/// is off or in docs mode (no rendering).
RenderGateway? buildRenderGateway(FluvieServerConfig config, ServerDependencies? api) {
  if (!config.enableMcp || config.mcpMode != McpMode.build) return null;
  if (api != null) return LocalRenderGateway(api);
  return ApiRenderGateway(baseUrl: config.remoteApiUrl!, apiToken: config.remoteApiToken);
}

/// Builds the MCP server (with its tools) when MCP is enabled, else `null`.
McpServer? buildMcpServer(
  FluvieServerConfig config, {
  DocSearchService? docs,
  RenderGateway? gateway,
  String schemaJson = '{}',
}) {
  if (!config.enableMcp) return null;
  return McpServer(
    name: _name,
    version: _version,
    tools: buildServerTools(
      mode: config.mcpMode,
      docs: docs,
      gateway: gateway,
      schemaJson: schemaJson,
    ),
  );
}
