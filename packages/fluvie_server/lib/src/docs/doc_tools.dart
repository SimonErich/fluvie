import 'dart:convert';

import 'package:fluvie_server/src/docs/doc_search_service.dart';
import 'package:fluvie_server/src/mcp/mcp_tool.dart';

/// Builds the documentation MCP tools over [docs].
///
/// These let a coding assistant learn Fluvie and author specs: list the pages,
/// full-text search them, and read one in full. They need no render backend, so
/// they are the whole tool set in docs mode and the base of it in build mode.
List<McpTool> buildDocTools(DocSearchService docs) => [
  McpTool(
    name: 'list_docs',
    description:
        'List every Fluvie documentation page as {path, title}. Use a path with '
        'get_doc to read a page in full.',
    inputSchema: const {'type': 'object', 'properties': <String, Object?>{}},
    handler: (_) async => McpToolResult.text(
      _json([
        for (final entry in docs.list()) {'path': entry.path, 'title': entry.title},
      ]),
    ),
  ),
  McpTool(
    name: 'search_docs',
    description:
        'Full-text search the Fluvie documentation. Returns the best matching '
        'pages as {path, title, snippet}; read a page with get_doc.',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'query': {'type': 'string', 'description': 'What to look for.'},
        'limit': {'type': 'integer', 'description': 'Max results (default 5).'},
      },
      'required': ['query'],
    },
    handler: (args) async {
      final query = args['query'];
      if (query is! String || query.isEmpty) {
        throw ArgumentError('Missing required "query" (expected a non-empty string).');
      }
      final hits = docs.search(query, limit: _limit(args['limit']));
      return McpToolResult.text(
        _json([
          for (final hit in hits) {'path': hit.path, 'title': hit.title, 'snippet': hit.snippet},
        ]),
      );
    },
  ),
  McpTool(
    name: 'get_doc',
    description:
        'Read one Fluvie documentation page in full by its path (from list_docs '
        'or search_docs).',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'path': {'type': 'string', 'description': 'The page path, e.g. "guides/ai-and-mcp.md".'},
      },
      'required': ['path'],
    },
    handler: (args) async {
      final path = args['path'];
      if (path is! String || path.isEmpty) {
        throw ArgumentError('Missing required "path" (expected a non-empty string).');
      }
      final page = docs.get(path);
      if (page == null) {
        return McpToolResult.text('No documentation page at "$path".', isError: true);
      }
      return McpToolResult.text(page.body);
    },
  ),
];

int _limit(Object? value) {
  if (value is int && value > 0) return value;
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null && parsed > 0) return parsed;
  }
  return 5;
}

String _json(Object? value) => const JsonEncoder.withIndent('  ').convert(value);
