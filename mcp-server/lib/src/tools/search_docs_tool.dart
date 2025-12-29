import '../indexing/search_engine.dart';
import '../mcp/mcp_types.dart';

/// Creates the searchDocs tool definition
ToolDefinition createSearchDocsTool() {
  return ToolDefinition(
    name: 'searchDocs',
    description:
        '''Search through Fluvie documentation to find relevant information about widgets, APIs, templates, and usage patterns.

Use this tool when:
- Looking for how to use a specific widget or feature
- Understanding Fluvie concepts like frame-based animation
- Finding code examples for specific use cases
- Learning about available templates and their configurations

Categories: all, widgets, templates, animations, effects, getting-started, advanced, helpers, concept''',
    inputSchema: {
      'type': 'object',
      'properties': {
        'query': {
          'type': 'string',
          'description':
              'Search query - can be natural language or specific terms like "AnimatedText", "Scene transitions", "embed video"',
        },
        'category': {
          'type': 'string',
          'enum': [
            'all',
            'widgets',
            'templates',
            'animations',
            'effects',
            'getting-started',
            'advanced',
            'helpers',
            'concept',
          ],
          'description': 'Optional category filter to narrow results',
        },
        'limit': {
          'type': 'integer',
          'default': 5,
          'description': 'Maximum number of results (1-10)',
        },
      },
      'required': ['query'],
    },
    handler: (args) async {
      final query = args['query'] as String;
      final category = args['category'] as String? ?? 'all';
      final limit = (args['limit'] as int? ?? 5).clamp(1, 10);

      final searchEngine = SearchEngine.instance;

      if (!searchEngine.isInitialized) {
        return ToolResult(
          content: [
            TextContent(
              'Search engine not initialized. Please ensure the server is properly configured.',
            ),
          ],
          isError: true,
        );
      }

      final results = await searchEngine.search(
        query: query,
        category: category,
        limit: limit,
      );

      if (results.isEmpty) {
        return ToolResult(
          content: [
            TextContent(
              'No results found for "$query"${category != 'all' ? ' in category "$category"' : ''}.\n\n'
              'Try:\n'
              '- Using different keywords\n'
              '- Searching in "all" categories\n'
              '- Using specific widget names like "Video", "Scene", "AnimatedText"',
            ),
          ],
        );
      }

      final buffer = StringBuffer();
      buffer.writeln('# Search Results for "$query"\n');

      for (var i = 0; i < results.length; i++) {
        final result = results[i];
        buffer.writeln('## ${i + 1}. ${result.document.title}');
        buffer.writeln('**Category:** ${result.document.category}');
        buffer.writeln('**File:** ${result.document.filePath}');
        buffer.writeln();
        buffer.writeln(result.snippet);
        buffer.writeln();

        if (result.document.sections.isNotEmpty) {
          buffer.writeln(
            '**Sections:** ${result.document.sections.take(5).join(', ')}',
          );
        }

        if (result.document.codeExamples.isNotEmpty) {
          buffer.writeln('\n**Code Example:**');
          buffer.writeln('```dart');
          buffer.writeln(
            result.document.codeExamples.first.length > 500
                ? '${result.document.codeExamples.first.substring(0, 500)}...'
                : result.document.codeExamples.first,
          );
          buffer.writeln('```');
        }

        buffer.writeln('\n---\n');
      }

      return ToolResult(
        content: [TextContent(buffer.toString())],
      );
    },
  );
}
