import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'package:fluvie_mcp_server/mcp_server.dart';

void main() async {
  // Load configuration
  final config = ServerConfig.fromEnvironment();

  // Configure logging
  configureLogging(config.logLevel);

  print('Starting Fluvie MCP Server...');
  print('Configuration: $config');

  // Initialize search engine with documentation
  print('Indexing documentation from: ${config.docsPath}');
  await SearchEngine.instance.initialize(config.docsPath);
  print('Indexed ${SearchEngine.instance.documentCount} documents');

  // Create tool registry and register tools
  final toolRegistry = ToolRegistry()
    ..register(createSearchDocsTool())
    ..register(createGetTemplateTool())
    ..register(createSuggestTemplatesTool())
    ..register(createGetWidgetReferenceTool())
    ..register(createGenerateCodeTool());

  print('Registered ${toolRegistry.count} tools');

  // Create resource registry
  final resourceRegistry = ResourceRegistry()
    ..addResource(
      ResourceDefinition(
        uri: 'fluvie://docs/ai-reference',
        name: 'Fluvie AI Reference',
        description: 'Complete AI-readable documentation for Fluvie',
        mimeType: 'text/markdown',
        handler: (uri, params) async {
          final file = File('${config.docsPath}/FLUVIE_AI_REFERENCE.md');
          if (await file.exists()) {
            return file.readAsString();
          }
          return '# Fluvie AI Reference\n\nDocumentation file not found.';
        },
      ),
    )
    ..addResource(
      ResourceDefinition(
        uri: 'fluvie://templates',
        name: 'Template Catalog',
        description: 'List of all available Fluvie templates',
        mimeType: 'application/json',
        handler: (uri, params) async {
          final templates = TemplateIndex.instance.getAllTemplates();
          return jsonEncode(templates.map((t) => t.toJson()).toList());
        },
      ),
    );

  // Create MCP handler
  final mcpHandler = McpHandler(
    toolRegistry: toolRegistry,
    resourceRegistry: resourceRegistry,
  );

  // Create SSE handler
  final sseHandler = SseHandler();

  // Build router
  final router = Router()
    // Health check
    ..get('/health', (Request request) {
      return Response.ok(
        jsonEncode({
          'status': 'healthy',
          'version': '1.0.0',
          'uptime': DateTime.now().millisecondsSinceEpoch,
          'indexes': {
            'docs': {
              'status': 'ready',
              'count': SearchEngine.instance.documentCount,
            },
            'templates': {
              'status': 'ready',
              'count': TemplateIndex.instance.getAllTemplates().length,
            },
          },
        }),
        headers: {'Content-Type': 'application/json'},
      );
    })

    // MCP JSON-RPC endpoint
    ..post('/mcp', (Request request) async {
      try {
        final body = await request.readAsString();
        final requestJson = jsonDecode(body) as Map<String, dynamic>;
        final response = await mcpHandler.handleRequest(requestJson);
        return Response.ok(
          jsonEncode(response),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({
            'jsonrpc': '2.0',
            'error': {'code': -32700, 'message': 'Parse error: $e'},
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }
    })

    // SSE endpoint for streaming
    ..get('/mcp/sse', (Request request) {
      return sseHandler.handleSse(request, mcpHandler.eventStream);
    })

    // Resource endpoint
    ..get('/resources/<path|.*>', (Request request, String path) async {
      try {
        final uri = 'fluvie://$path';
        final resource = await mcpHandler.readResource(uri);
        return Response.ok(
          jsonEncode(resource),
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return Response.notFound(
          jsonEncode({'error': 'Resource not found: $path'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    })

    // API documentation
    ..get('/', (Request request) {
      return Response.ok(
        '''
<!DOCTYPE html>
<html>
<head>
  <title>Fluvie MCP Server</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 800px; margin: 40px auto; padding: 20px; }
    h1 { color: #e94560; }
    code { background: #f4f4f4; padding: 2px 6px; border-radius: 4px; }
    pre { background: #f4f4f4; padding: 15px; border-radius: 8px; overflow-x: auto; }
  </style>
</head>
<body>
  <h1>Fluvie MCP Server</h1>
  <p>Model Context Protocol server for the Fluvie video composition library.</p>

  <h2>Endpoints</h2>
  <ul>
    <li><code>GET /health</code> - Health check</li>
    <li><code>POST /mcp</code> - MCP JSON-RPC endpoint</li>
    <li><code>GET /mcp/sse</code> - Server-Sent Events stream</li>
    <li><code>GET /resources/{path}</code> - Resource access</li>
  </ul>

  <h2>Available Tools</h2>
  <ul>
    <li><code>searchDocs</code> - Search documentation</li>
    <li><code>getTemplate</code> - Get template details</li>
    <li><code>suggestTemplates</code> - Get template recommendations</li>
    <li><code>getWidgetReference</code> - Get widget documentation</li>
    <li><code>generateCode</code> - Generate Fluvie code</li>
  </ul>

  <h2>Client Configuration</h2>
  <p>Add to your MCP client configuration:</p>
  <pre>{
  "mcpServers": {
    "fluvie": {
      "url": "https://mcp.fluvie.at/mcp",
      "transport": "http"
    }
  }
}</pre>

  <h2>Documentation</h2>
  <p>Visit <a href="https://github.com/simonerich/fluvie">github.com/simonerich/fluvie</a> for full documentation.</p>
</body>
</html>
''',
        headers: {'Content-Type': 'text/html'},
      );
    });

  // Build pipeline with middleware
  final handler = const Pipeline()
      .addMiddleware(loggingMiddleware())
      .addMiddleware(corsMiddleware())
      .addHandler(router.call);

  // Start server
  final server = await shelf_io.serve(
    handler,
    config.host,
    config.port,
  );

  print('');
  print('Fluvie MCP Server running!');
  print('  URL: http://${server.address.host}:${server.port}');
  print('  Health: http://${server.address.host}:${server.port}/health');
  print('  MCP: http://${server.address.host}:${server.port}/mcp');
  print('');
  print('Press Ctrl+C to stop.');
}
