import 'dart:convert';

import 'package:fluvie_server/src/config/mcp_mode.dart';
import 'package:fluvie_server/src/docs/doc_search_service.dart';
import 'package:fluvie_server/src/docs/doc_tools.dart';
import 'package:fluvie_server/src/mcp/fluvie_tools.dart';
import 'package:fluvie_server/src/mcp/mcp_tool.dart';
import 'package:fluvie_server/src/mcp/render_gateway.dart';

/// Builds the MCP tool set for the given [mode].
///
/// Docs tools come first when [docs] is set. In [McpMode.build] the render and
/// schema tools come from [gateway] (they need a backend); in [McpMode.docs] only
/// a schema tool is added, served from the bundled [schemaJson] with no backend.
List<McpTool> buildServerTools({
  required McpMode mode,
  DocSearchService? docs,
  RenderGateway? gateway,
  String schemaJson = '{}',
}) => [
  if (docs != null) ...buildDocTools(docs),
  if (mode == McpMode.build && gateway != null)
    ...buildFluvieTools(gateway)
  else
    _schemaTool(schemaJson),
];

/// A `get_video_spec_schema` tool that serves the bundled schema with no backend.
McpTool _schemaTool(String schemaJson) => McpTool(
  name: 'get_video_spec_schema',
  description: 'Fetch the Fluvie VideoSpec JSON Schema so you can author valid specs.',
  inputSchema: const {'type': 'object', 'properties': <String, Object?>{}},
  handler: (_) async {
    final decoded = jsonDecode(schemaJson);
    return McpToolResult.text(const JsonEncoder.withIndent('  ').convert(decoded));
  },
);
