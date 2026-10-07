import 'package:fluvie_server/src/mcp/fluvie_tools.dart';
import 'package:test/test.dart';

import '../../tool/export_protocol_reference.dart';
import '../mcp/fakes/fake_render_gateway.dart';

void main() {
  test('published protocol examples use the actual request parser and MCP registry', () async {
    final gateway = FakeRenderGateway();
    final reference = buildProtocolReference(gateway);
    expect(reference['schemaVersion'], 1);
    final examples = reference['examples']! as Map<String, Object?>;
    expect(examples['http'], {
      'method': 'POST',
      'path': '/v1/renders',
      'body': {
        'prompt': 'A 4-second teal title card saying Hello, Fluvie.',
        'options': {'format': 'mp4', 'aspect': 'reels'},
      },
    });
    final mcp = examples['mcp']! as Map<String, Object?>;
    expect(mcp['method'], 'tools/call');
    final params = mcp['params']! as Map<String, Object?>;
    expect(params['name'], 'generate_video');
    final arguments = params['arguments']! as Map<String, Object?>;
    await buildFluvieTools(
      gateway,
    ).singleWhere((tool) => tool.name == params['name']).handler(arguments);
    expect(gateway.lastRequest!.toJson(), (examples['http']! as Map)['body']);
    expect(arguments['prompt'], isNotEmpty);
  });

  test('MCP export options advertise only accepted HTTP values', () {
    final tool = buildFluvieTools(FakeRenderGateway()).first;
    final properties = tool.inputSchema['properties']! as Map<String, Object?>;
    expect((properties['aspect']! as Map)['enum'], ['reels', 'square', 'landscape', 'portrait45']);
    expect((properties['format']! as Map)['enum'], ['mp4', 'gif', 'transparent']);
  });
}
