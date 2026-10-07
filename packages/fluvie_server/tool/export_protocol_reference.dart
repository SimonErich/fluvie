import 'dart:convert';
import 'dart:io';

import 'package:fluvie_server/client.dart';
import 'package:fluvie_server/src/api/render/render_request.dart';
import 'package:fluvie_server/src/mcp/fluvie_tools.dart';
import 'package:fluvie_server/src/mcp/render_gateway.dart';

/// Exports examples using the same serializers, parser and tool registry as the server.
Map<String, Object?> buildProtocolReference(RenderGateway gateway) {
  const prompt = 'A 4-second teal title card saying Hello, Fluvie.';
  final body = ApiRenderRequest.prompt(prompt, format: 'mp4', aspect: 'reels').toJson();
  RenderRequest.fromJson(body);
  final tools = buildFluvieTools(gateway);
  final generate = tools.singleWhere((tool) => tool.name == 'generate_video');
  final properties = generate.inputSchema['properties']! as Map<String, Object?>;
  final arguments = <String, Object?>{'prompt': prompt, 'format': 'mp4', 'aspect': 'reels'};
  if (!arguments.keys.every(properties.containsKey)) {
    throw StateError('Published MCP example uses an argument absent from the tool schema.');
  }
  return {
    'schemaVersion': 1,
    'tools': tools.map((tool) => tool.toDescriptor()).toList(),
    'examples': {
      'http': {'method': 'POST', 'path': '/v1/renders', 'body': body},
      'mcp': {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'tools/call',
        'params': {'name': generate.name, 'arguments': arguments},
      },
    },
  };
}

/// Writes the source-derived protocol reference to standard output without contacting a server.
void main() => stdout.writeln(
  const JsonEncoder.withIndent('  ').convert(buildProtocolReference(_ReferenceGateway())),
);

final class _ReferenceGateway implements RenderGateway {
  @override
  Future<RenderJobView> render(ApiRenderRequest request) =>
      throw UnsupportedError('Reference only');

  @override
  Future<ApiValidationResult> validate(String code) => throw UnsupportedError('Reference only');

  @override
  Future<Map<String, Object?>> fetchSpecSchema() => throw UnsupportedError('Reference only');

  @override
  void close() {}
}
