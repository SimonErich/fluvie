import 'package:fluvie_server/src/mcp/mcp.dart';
import 'package:test/test.dart';

void main() {
  group('McpToolResult', () {
    test('text builds a single text block', () {
      final result = McpToolResult.text('hi');
      expect(result.isError, isFalse);
      expect(result.content, [
        {'type': 'text', 'text': 'hi'},
      ]);
      expect(result.toJson(), {
        'content': [
          {'type': 'text', 'text': 'hi'},
        ],
        'isError': false,
      });
    });

    test('marks tool-level errors', () {
      expect(McpToolResult.text('boom', isError: true).isError, isTrue);
    });
  });

  group('McpTool', () {
    test('toDescriptor omits the handler', () {
      final tool = McpTool(
        name: 'x',
        description: 'd',
        inputSchema: const {'type': 'object'},
        handler: (args) async => McpToolResult.text('y'),
      );
      expect(tool.toDescriptor(), {
        'name': 'x',
        'description': 'd',
        'inputSchema': {'type': 'object'},
      });
    });
  });
}
