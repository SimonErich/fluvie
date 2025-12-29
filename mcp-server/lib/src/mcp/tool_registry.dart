import 'mcp_types.dart';

/// Registry for MCP tools
class ToolRegistry {
  final Map<String, ToolDefinition> _tools = {};

  /// Register a tool
  void register(ToolDefinition tool) {
    _tools[tool.name] = tool;
  }

  /// List all registered tools
  List<Map<String, dynamic>> listTools() {
    return _tools.values.map((t) => t.toJson()).toList();
  }

  /// Get a tool by name
  ToolDefinition? getTool(String name) {
    return _tools[name];
  }

  /// Call a tool by name with arguments
  Future<ToolResult> callTool(String name, Map<String, dynamic> args) async {
    final tool = _tools[name];
    if (tool == null) {
      throw McpError('Tool not found: $name', code: -32601);
    }
    return tool.handler(args);
  }

  /// Check if a tool exists
  bool hasTool(String name) => _tools.containsKey(name);

  /// Get the number of registered tools
  int get count => _tools.length;
}
