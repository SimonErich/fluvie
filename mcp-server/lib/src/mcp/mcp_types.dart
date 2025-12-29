/// MCP Protocol Types
///
/// Based on the Model Context Protocol specification
library;

/// Result from a tool execution
class ToolResult {
  final List<ContentBlock> content;
  final bool isError;

  const ToolResult({
    required this.content,
    this.isError = false,
  });

  Map<String, dynamic> toJson() => {
        'content': content.map((c) => c.toJson()).toList(),
        if (isError) 'isError': true,
      };
}

/// Content block in tool results
abstract class ContentBlock {
  Map<String, dynamic> toJson();
}

/// Text content block
class TextContent extends ContentBlock {
  final String text;

  TextContent(this.text);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'text',
        'text': text,
      };
}

/// Resource content block
class ResourceContent extends ContentBlock {
  final String uri;
  final String mimeType;
  final String? text;

  ResourceContent({
    required this.uri,
    required this.mimeType,
    this.text,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'resource',
        'resource': {
          'uri': uri,
          'mimeType': mimeType,
          if (text != null) 'text': text,
        },
      };
}

/// Tool definition
class ToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;
  final Future<ToolResult> Function(Map<String, dynamic> arguments) handler;

  const ToolDefinition({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.handler,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'inputSchema': inputSchema,
      };
}

/// Resource definition
class ResourceDefinition {
  final String uri;
  final String name;
  final String description;
  final String mimeType;
  final Future<String> Function(String uri, Map<String, String> params) handler;

  const ResourceDefinition({
    required this.uri,
    required this.name,
    required this.description,
    required this.mimeType,
    required this.handler,
  });

  Map<String, dynamic> toJson() => {
        'uri': uri,
        'name': name,
        'description': description,
        'mimeType': mimeType,
      };
}

/// Prompt argument definition
class PromptArgument {
  final String name;
  final bool required;
  final String description;

  const PromptArgument({
    required this.name,
    required this.required,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'required': required,
        'description': description,
      };
}

/// Prompt definition
class PromptDefinition {
  final String name;
  final String description;
  final List<PromptArgument> arguments;
  final Future<PromptResult> Function(Map<String, dynamic> args) handler;

  const PromptDefinition({
    required this.name,
    required this.description,
    required this.arguments,
    required this.handler,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'arguments': arguments.map((a) => a.toJson()).toList(),
      };
}

/// Result from prompt generation
class PromptResult {
  final String? description;
  final List<PromptMessage> messages;

  const PromptResult({
    this.description,
    required this.messages,
  });

  Map<String, dynamic> toJson() => {
        if (description != null) 'description': description,
        'messages': messages.map((m) => m.toJson()).toList(),
      };
}

/// Message in a prompt result
class PromptMessage {
  final String role;
  final String content;

  const PromptMessage({
    required this.role,
    required this.content,
  });

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': {'type': 'text', 'text': content},
      };
}

/// MCP Error
class McpError implements Exception {
  final int code;
  final String message;
  final dynamic data;

  const McpError(this.message, {this.code = -32603, this.data});

  @override
  String toString() => 'McpError: $message (code: $code)';

  Map<String, dynamic> toJson() => {
        'code': code,
        'message': message,
        if (data != null) 'data': data,
      };
}
