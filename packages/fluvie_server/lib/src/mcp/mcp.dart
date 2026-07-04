/// An MCP server that lets an AI assistant author and render Fluvie videos.
///
/// Expose the tools over stdio (a local assistant such as Claude Code) or HTTP
/// (a hosted endpoint like `mcp.fluvie.dev`). Rendering is delegated to a running
/// Fluvie render API, so this package stays small and needs no Flutter or FFmpeg.
library;

export 'api_render_gateway.dart';
export 'fluvie_tools.dart';
export 'http_transport.dart';
export 'jsonrpc.dart';
export 'mcp_server.dart';
export 'mcp_tool.dart';
export 'render_gateway.dart';
export 'mcp_server_config.dart';
export 'stdio_transport.dart';
