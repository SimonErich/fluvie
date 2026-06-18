import 'package:fluvie_mcp/src/jsonrpc.dart';
import 'package:fluvie_mcp/src/mcp_tool.dart';

/// The protocol version this server advertises when a client does not pin one.
const String defaultMcpProtocolVersion = '2025-06-18';

/// A transport-agnostic MCP server.
///
/// It turns one decoded JSON-RPC message into one response map (or `null` for
/// notifications, which get no reply). Wire it to a transport: stdio for a local
/// assistant, HTTP for a hosted endpoint.
final class McpServer {
  /// Creates a server named [name] at [version] exposing [tools].
  McpServer({
    required this.name,
    required this.version,
    required List<McpTool> tools,
    this.protocolVersion = defaultMcpProtocolVersion,
  }) : _tools = {for (final tool in tools) tool.name: tool};

  /// The server name reported in `initialize`.
  final String name;

  /// The server version reported in `initialize`.
  final String version;

  /// The protocol version advertised when the client does not pin one.
  final String protocolVersion;

  final Map<String, McpTool> _tools;

  /// The tools this server exposes, in registration order.
  Iterable<McpTool> get tools => _tools.values;

  /// Handles one decoded JSON-RPC [message], returning the response map, or
  /// `null` when the message is a notification (which gets no reply).
  Future<Map<String, Object?>?> handle(Map<String, Object?> message) async {
    final id = message['id'];
    final method = message['method'];
    if (method is! String) {
      return id == null ? null : jsonRpcError(id, jsonRpcInvalidRequest, 'Missing method');
    }
    if (method.startsWith('notifications/')) return null;
    switch (method) {
      case 'initialize':
        return jsonRpcResult(id, _initialize(message['params']));
      case 'ping':
        return jsonRpcResult(id, const {});
      case 'tools/list':
        return jsonRpcResult(id, {
          'tools': [for (final tool in _tools.values) tool.toDescriptor()],
        });
      case 'tools/call':
        return _callTool(id, message['params']);
      default:
        return id == null
            ? null
            : jsonRpcError(id, jsonRpcMethodNotFound, 'Unknown method: $method');
    }
  }

  Map<String, Object?> _initialize(Object? params) {
    final Object? requested = params is Map ? params['protocolVersion'] : null;
    return {
      'protocolVersion': requested is String ? requested : protocolVersion,
      'capabilities': const {'tools': <String, Object?>{}},
      'serverInfo': {'name': name, 'version': version},
    };
  }

  Future<Map<String, Object?>> _callTool(Object? id, Object? params) async {
    if (params is! Map) {
      return jsonRpcError(id, jsonRpcInvalidParams, 'Invalid tools/call params');
    }
    final Object? toolName = params['name'];
    final tool = toolName is String ? _tools[toolName] : null;
    if (tool == null) {
      return jsonRpcError(id, jsonRpcInvalidParams, 'Unknown tool: $toolName');
    }
    final Object? rawArgs = params['arguments'];
    final args = rawArgs is Map ? rawArgs.cast<String, Object?>() : <String, Object?>{};
    try {
      final result = await tool.handler(args);
      return jsonRpcResult(id, result.toJson());
    } on Object catch (error) {
      return jsonRpcResult(id, McpToolResult.text('$error', isError: true).toJson());
    }
  }
}
