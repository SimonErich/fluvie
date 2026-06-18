import 'package:fluvie_api/client.dart';
import 'package:fluvie_mcp/fluvie_mcp.dart';
import 'package:test/test.dart';

import 'fake_render_gateway.dart';

McpTool _tool(List<McpTool> tools, String name) => tools.firstWhere((t) => t.name == name);

void main() {
  group('buildFluvieTools', () {
    test('exposes the five tools in order', () {
      final tools = buildFluvieTools(FakeRenderGateway());
      expect(tools.map((t) => t.name), [
        'generate_video',
        'edit_video',
        'render_video',
        'render_composition',
        'get_video_spec_schema',
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

    test('get_video_spec_schema returns the schema JSON', () async {
      final gateway = FakeRenderGateway(schema: {'type': 'object', 'title': 'VideoSpec'});
      final result = await _tool(buildFluvieTools(gateway), 'get_video_spec_schema').handler(
        <String, Object?>{},
      );
      expect(result.content.first['text'], contains('VideoSpec'));
    });
  });
}
