import 'package:fluvie_server/src/app/server_tools.dart';
import 'package:fluvie_server/src/config/mcp_mode.dart';
import 'package:fluvie_server/src/docs/doc_search_service.dart';
import 'package:fluvie_server/src/mcp/mcp_tool.dart';
import 'package:test/test.dart';

import '../docs/fake_doc_repository.dart';
import '../mcp/fake_render_gateway.dart';

void main() {
  late DocSearchService docs;

  setUp(() => docs = DocSearchService.fromRepository(FakeDocRepository.sample()));

  List<String> names(List<McpTool> tools) => [for (final t in tools) t.name];

  test('docs mode exposes the doc tools and a schema tool, no render tools', () {
    final tools = buildServerTools(mode: McpMode.docs, docs: docs);

    expect(
      names(tools),
      containsAll(['list_docs', 'search_docs', 'get_doc', 'get_video_spec_schema']),
    );
    expect(names(tools), isNot(contains('generate_video')));
  });

  test('build mode adds the render tools from the gateway', () {
    final tools = buildServerTools(
      mode: McpMode.build,
      docs: docs,
      gateway: FakeRenderGateway(),
    );

    expect(
      names(tools),
      containsAll([
        'list_docs',
        'generate_video',
        'edit_video',
        'render_video',
        'render_composition',
        'get_video_spec_schema',
      ]),
    );
  });

  test('build mode without docs is just the render tools', () {
    final tools = buildServerTools(mode: McpMode.build, gateway: FakeRenderGateway());

    expect(names(tools), isNot(contains('list_docs')));
    expect(names(tools), contains('generate_video'));
  });

  test('docs mode without docs is just the schema tool', () {
    final tools = buildServerTools(mode: McpMode.docs);

    expect(names(tools), ['get_video_spec_schema']);
  });

  test('the bundled schema tool serves the configured schema', () async {
    final tools = buildServerTools(mode: McpMode.docs, schemaJson: '{"type":"object"}');
    final schema = tools.firstWhere((t) => t.name == 'get_video_spec_schema');

    final result = await schema.handler(const {});

    expect(result.content.single['text'], contains('"type": "object"'));
  });
}
