/// An MCP server that lets an AI assistant author and render Fluvie videos.
///
/// Expose the tools over stdio (a local assistant such as Claude Code) or HTTP
/// (a hosted endpoint like `mcp.fluvie.dev`). Rendering is delegated to a running
/// Fluvie render API, so this package stays small and needs no Flutter or FFmpeg.
library;

export 'src/api_render_gateway.dart';
export 'src/fluvie_tools.dart';
export 'src/http_transport.dart';
export 'src/jsonrpc.dart';
export 'src/mcp_server.dart';
export 'src/mcp_tool.dart';
export 'src/render_gateway.dart';
export 'src/server_config.dart';
export 'src/stdio_transport.dart';
