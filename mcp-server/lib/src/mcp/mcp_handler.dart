import 'dart:async';
import 'dart:convert';

import 'mcp_types.dart';
import 'tool_registry.dart';
import 'resource_registry.dart';

/// Main MCP protocol handler
class McpHandler {
  final ToolRegistry toolRegistry;
  final ResourceRegistry resourceRegistry;

  /// Stream controller for SSE events
  final _eventController = StreamController<String>.broadcast();

  /// Get the event stream for SSE
  Stream<String> get eventStream => _eventController.stream;

  McpHandler({
    required this.toolRegistry,
    required this.resourceRegistry,
  });

  /// Handle an incoming MCP JSON-RPC request
  Future<Map<String, dynamic>> handleRequest(Map<String, dynamic> request) async {
    final method = request['method'] as String?;
    final params = request['params'] as Map<String, dynamic>?;
    final id = request['id'];

    if (method == null) {
      return _errorResponse(id, -32600, 'Invalid request: missing method');
    }

    try {
      final result = await _dispatchMethod(method, params ?? {});
      return _successResponse(id, result);
    } on McpError catch (e) {
      return _errorResponse(id, e.code, e.message, e.data);
    } catch (e, stack) {
      return _errorResponse(id, -32603, 'Internal error: $e', stack.toString());
    }
  }

  /// Dispatch to the appropriate method handler
  Future<Map<String, dynamic>> _dispatchMethod(
    String method,
    Map<String, dynamic> params,
  ) async {
    switch (method) {
      case 'initialize':
        return _handleInitialize(params);

      case 'tools/list':
        return _handleToolsList();

      case 'tools/call':
        return await _handleToolsCall(params);

      case 'resources/list':
        return _handleResourcesList();

      case 'resources/read':
        return await _handleResourcesRead(params);

      case 'ping':
        return {};

      default:
        throw McpError('Method not found: $method', code: -32601);
    }
  }

  /// Handle initialize request
  Map<String, dynamic> _handleInitialize(Map<String, dynamic> params) {
    return {
      'protocolVersion': '2024-11-05',
      'serverInfo': {
        'name': 'fluvie-mcp-server',
        'version': '1.0.0',
      },
      'capabilities': {
        'tools': {'listChanged': false},
        'resources': {'subscribe': false, 'listChanged': false},
      },
    };
  }

  /// Handle tools/list request
  Map<String, dynamic> _handleToolsList() {
    return {
      'tools': toolRegistry.listTools(),
    };
  }

  /// Handle tools/call request
  Future<Map<String, dynamic>> _handleToolsCall(
    Map<String, dynamic> params,
  ) async {
    final name = params['name'] as String?;
    final arguments = params['arguments'] as Map<String, dynamic>? ?? {};

    if (name == null) {
      throw McpError('Missing tool name', code: -32602);
    }

    final result = await toolRegistry.callTool(name, arguments);
    return result.toJson();
  }

  /// Handle resources/list request
  Map<String, dynamic> _handleResourcesList() {
    return {
      'resources': resourceRegistry.listResources(),
    };
  }

  /// Handle resources/read request
  Future<Map<String, dynamic>> _handleResourcesRead(
    Map<String, dynamic> params,
  ) async {
    final uri = params['uri'] as String?;

    if (uri == null) {
      throw McpError('Missing resource URI', code: -32602);
    }

    final content = await resourceRegistry.readResource(uri);
    return {
      'contents': [
        {
          'uri': uri,
          'mimeType': 'text/markdown',
          'text': content,
        }
      ],
    };
  }

  /// Read a resource (public method for direct access)
  Future<Map<String, dynamic>> readResource(String uri) async {
    return _handleResourcesRead({'uri': uri});
  }

  /// Emit an SSE event
  void emitEvent(String eventType, Map<String, dynamic> data) {
    final event = jsonEncode({
      'type': eventType,
      'data': data,
    });
    _eventController.add(event);
  }

  /// Create a success response
  Map<String, dynamic> _successResponse(dynamic id, Map<String, dynamic> result) {
    return {
      'jsonrpc': '2.0',
      'id': id,
      'result': result,
    };
  }

  /// Create an error response
  Map<String, dynamic> _errorResponse(
    dynamic id,
    int code,
    String message, [
    dynamic data,
  ]) {
    return {
      'jsonrpc': '2.0',
      'id': id,
      'error': {
        'code': code,
        'message': message,
        if (data != null) 'data': data,
      },
    };
  }

  /// Dispose resources
  void dispose() {
    _eventController.close();
  }
}
