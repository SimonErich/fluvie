import 'package:meta/meta.dart';

/// The result a tool returns: one or more content blocks and a flag marking
/// tool-level failures (as opposed to protocol errors).
@immutable
final class McpToolResult {
  /// Creates a result from raw MCP content blocks.
  const McpToolResult(this.content, {this.isError = false});

  /// A single text block, the common case.
  factory McpToolResult.text(String text, {bool isError = false}) => McpToolResult(
    [
      {'type': 'text', 'text': text},
    ],
    isError: isError,
  );

  /// The MCP content blocks (for example `{'type': 'text', 'text': ...}`).
  final List<Map<String, Object?>> content;

  /// Whether the call failed at the tool level.
  final bool isError;

  /// The result as the `tools/call` result map.
  Map<String, Object?> toJson() => {'content': content, 'isError': isError};
}

/// Runs one `tools/call`, given its decoded [arguments].
typedef McpToolHandler = Future<McpToolResult> Function(Map<String, Object?> arguments);

/// A single MCP tool: its name, description, argument schema, and handler.
@immutable
final class McpTool {
  /// Creates a tool.
  const McpTool({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.handler,
  });

  /// The name the client calls.
  final String name;

  /// A one-line description shown to the model.
  final String description;

  /// The JSON Schema for the tool's arguments.
  final Map<String, Object?> inputSchema;

  /// Runs the tool.
  final McpToolHandler handler;

  /// The tool as a `tools/list` descriptor (without the handler).
  Map<String, Object?> toDescriptor() => {
    'name': name,
    'description': description,
    'inputSchema': inputSchema,
  };
}
