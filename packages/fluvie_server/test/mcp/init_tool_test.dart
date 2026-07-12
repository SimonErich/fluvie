import 'package:fluvie_server/src/mcp/init_tool.dart';
import 'package:test/test.dart';

void main() {
  group('init_project tool', () {
    test('is tagged for Flutter-style / real-code requests', () {
      final tool = buildInitProjectTool();
      expect(tool.name, 'init_project');
      expect(tool.description.toLowerCase(), contains('flutter style'));
      expect(tool.description.toLowerCase(), contains('real code'));
    });

    test('returns the starter, the deps, and the fluvie init command', () async {
      final result = await buildInitProjectTool().handler(const {});
      final text = result.content.single['text']! as String;

      expect(result.isError, isFalse);
      expect(text, contains('fluvie init'));
      expect(text, contains('Video starterVideo()'));
      expect(text, contains('fluvie: ^0.2.0'));
      expect(text, contains('validate_code'));
    });
  });
}
