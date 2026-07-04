import 'package:fluvie_server/client.dart';
import 'package:fluvie_server/src/mcp/mcp.dart';
import 'package:test/test.dart';

import 'fakes/fake_render_gateway.dart';

McpTool _tool(List<McpTool> tools, String name) => tools.firstWhere((t) => t.name == name);

void main() {
  group('buildFluvieTools', () {
    test('exposes the tools in order', () {
      final tools = buildFluvieTools(FakeRenderGateway());
      expect(tools.map((t) => t.name), [
        'generate_video',
        'edit_video',
        'validate_code',
        'render_video',
        'render_composition',
        'get_video_spec_schema',
        'spec_to_dart',
      ]);
    });

    test('generate_video sends a prompt request and returns the video URL', () async {
      final gateway = FakeRenderGateway(
        job: RenderJobView(
          id: 'j',
          status: 'succeeded',
          video: FileLink(downloadUrl: Uri.parse('https://x/v.mp4')),
        ),
      );
      final result = await _tool(buildFluvieTools(gateway), 'generate_video').handler({
        'prompt': 'a title card',
        'aspect': '9:16',
      });
      final request = gateway.lastRequest!.toJson();
      expect(request['prompt'], 'a title card');
      expect((request['options']! as Map)['aspect'], '9:16');
      expect(result.content.first['text'], contains('https://x/v.mp4'));
      expect(result.isError, isFalse);
    });

    test('edit_video requires base and change', () {
      final tools = buildFluvieTools(FakeRenderGateway());
      expect(
        _tool(tools, 'edit_video').handler({'change': 'x'}),
        throwsArgumentError,
      );
    });

    test('edit_video sends an edit request', () async {
      final gateway = FakeRenderGateway();
      await _tool(buildFluvieTools(gateway), 'edit_video').handler({
        'base': {'fps': 30},
        'change': 'make it yellow',
      });
      final edit = gateway.lastRequest!.toJson()['edit']! as Map;
      expect(edit['change'], 'make it yellow');
      expect((edit['base']! as Map)['fps'], 30);
    });

    test('render_video sends a spec request', () async {
      final gateway = FakeRenderGateway();
      await _tool(buildFluvieTools(gateway), 'render_video').handler({
        'spec': {'fps': 24},
      });
      expect((gateway.lastRequest!.toJson()['spec']! as Map)['fps'], 24);
    });

    test('render_composition sends a key request', () async {
      final gateway = FakeRenderGateway();
      await _tool(buildFluvieTools(gateway), 'render_composition').handler({'key': 'demo'});
      expect(gateway.lastRequest!.toJson()['key'], 'demo');
    });

    test('reports when no downloadable file came back', () async {
      final gateway = FakeRenderGateway(
        job: const RenderJobView(id: 'j', status: 'succeeded'),
      );
      final result = await _tool(buildFluvieTools(gateway), 'render_composition').handler({
        'key': 'demo',
      });
      expect(result.content.first['text'], contains('no downloadable file'));
    });

    test('includes a poster URL when present', () async {
      final gateway = FakeRenderGateway(
        job: RenderJobView(
          id: 'j',
          status: 'succeeded',
          video: FileLink(downloadUrl: Uri.parse('https://x/v.mp4')),
          poster: FileLink(downloadUrl: Uri.parse('https://x/p.png')),
        ),
      );
      final result = await _tool(buildFluvieTools(gateway), 'render_video').handler({
        'spec': <String, Object?>{},
      });
      expect(result.content.first['text'], contains('Poster: https://x/p.png'));
    });

    test('validate_code passes the code to the gateway and reports a clean result', () async {
      final gateway = FakeRenderGateway();
      final result = await _tool(buildFluvieTools(gateway), 'validate_code').handler({
        'code': 'Video build() => Video(scenes: const []);',
      });
      expect(gateway.lastValidatedCode, contains('Video build()'));
      expect(result.isError, isFalse);
      expect(result.content.first['text'], contains('OK'));
    });

    test('validate_code reports diagnostics and marks an error', () async {
      final gateway = FakeRenderGateway(
        validation: const ApiValidationResult(
          ok: false,
          diagnostics: [
            ApiCodeDiagnostic(
              severity: ApiDiagnosticSeverity.error,
              message: "Target of URI doesn't exist: 'dart:io'.",
              line: 1,
              column: 8,
              code: 'uri_does_not_exist',
            ),
          ],
        ),
      );
      final result = await _tool(buildFluvieTools(gateway), 'validate_code').handler({
        'code': "import 'dart:io';",
      });
      expect(result.isError, isTrue);
      expect(result.content.first['text'], contains('Not ready to render'));
      expect(result.content.first['text'], contains('uri_does_not_exist'));
    });

    test('validate_code shows warnings but still allows a render', () async {
      final gateway = FakeRenderGateway(
        validation: const ApiValidationResult(
          ok: true,
          diagnostics: [
            ApiCodeDiagnostic(
              severity: ApiDiagnosticSeverity.warning,
              message: 'unused import',
              line: 2,
              column: 1,
            ),
          ],
        ),
      );
      final result = await _tool(buildFluvieTools(gateway), 'validate_code').handler({'code': 'x'});

      expect(result.isError, isFalse);
      expect(result.content.first['text'], contains('OK to render, with 1 warning'));
      expect(result.content.first['text'], contains('unused import'));
    });

    test('validate_code requires a non-empty code string', () {
      expect(
        _tool(buildFluvieTools(FakeRenderGateway()), 'validate_code').handler(<String, Object?>{}),
        throwsArgumentError,
      );
    });

    test('get_video_spec_schema returns the schema JSON', () async {
      final gateway = FakeRenderGateway(schema: {'type': 'object', 'title': 'VideoSpec'});
      final result = await _tool(buildFluvieTools(gateway), 'get_video_spec_schema').handler(
        <String, Object?>{},
      );
      expect(result.content.first['text'], contains('VideoSpec'));
    });

    test('generate_video surfaces the editable Dart code when present', () async {
      final gateway = FakeRenderGateway(
        job: RenderJobView(
          id: 'j',
          status: 'succeeded',
          video: FileLink(downloadUrl: Uri.parse('https://x/v.mp4')),
          code: "import 'package:fluvie/fluvie.dart';\n\nVideo build() {}",
        ),
      );
      final result = await _tool(buildFluvieTools(gateway), 'generate_video').handler({
        'prompt': 'a title card',
      });
      final text = result.content.first['text']! as String;
      expect(text, contains('Flutter-style Dart'));
      expect(text, contains('Video build()'));
    });

    test('spec_to_dart prints a VideoSpec as a Video build() snippet', () async {
      final result = await _tool(buildFluvieTools(FakeRenderGateway()), 'spec_to_dart').handler({
        'spec': {
          'fluvieSpec': 1,
          'scenes': [
            {
              'duration': '2s',
              'children': [
                {'type': 'Text', 'text': 'hi'},
              ],
            },
          ],
        },
      });
      final text = result.content.first['text']! as String;
      expect(result.isError, isFalse);
      expect(text, contains('Video build()'));
      expect(text, contains("Text('hi')"));
    });

    test('spec_to_dart reports a malformed spec as a tool error', () async {
      final result = await _tool(buildFluvieTools(FakeRenderGateway()), 'spec_to_dart').handler({
        'spec': {
          'fluvieSpec': 1,
          'scenes': [
            {
              'duration': '2s',
              'children': [
                {'type': 'Bogus'},
              ],
            },
          ],
        },
      });
      expect(result.isError, isTrue);
      expect(result.content.first['text'], contains('Could not convert the spec'));
    });

    test('spec_to_dart requires a spec object', () {
      expect(
        _tool(buildFluvieTools(FakeRenderGateway()), 'spec_to_dart').handler(<String, Object?>{}),
        throwsArgumentError,
      );
    });
  });
}
