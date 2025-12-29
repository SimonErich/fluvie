/// Fluvie MCP Server Library
///
/// Provides Model Context Protocol server functionality for the Fluvie
/// video composition library.
library;

export 'src/config/server_config.dart';
export 'src/indexing/doc_indexer.dart';
export 'src/indexing/search_engine.dart';
export 'src/indexing/template_index.dart';
export 'src/mcp/mcp_handler.dart';
export 'src/mcp/mcp_types.dart';
export 'src/mcp/resource_registry.dart';
export 'src/mcp/sse_handler.dart';
export 'src/mcp/tool_registry.dart';
export 'src/middleware/cors_middleware.dart';
export 'src/middleware/logging_middleware.dart';
export 'src/tools/generate_code_tool.dart';
export 'src/tools/get_template_tool.dart';
export 'src/tools/get_widget_ref_tool.dart';
export 'src/tools/search_docs_tool.dart';
export 'src/tools/suggest_templates_tool.dart';
