import 'dart:convert';

import 'package:fluvie_server/src/mcp/mcp.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

McpServer _server() => McpServer(
  name: 'fluvie',
  version: '0.1.0',
  tools: [
    McpTool(
      name: 'echo',
      description: 'Echoes.',
      inputSchema: const {'type': 'object'},
      handler: (args) async => McpToolResult.text('ok'),
    ),
  ],
);

Request _post(String body, {Map<String, String>? headers}) => Request(
  'POST',
  Uri.parse('http://localhost/mcp'),
  headers: {'content-type': 'application/json', ...?headers},
  body: body,
);

void main() {
  group('mcpHttpHandler', () {
    test('handles a JSON-RPC request', () async {
      final handler = mcpHttpHandler(_server());
      final response = await handler(_post(jsonEncode({'id': 1, 'method': 'tools/list'})));
      expect(response.statusCode, 200);
      final decoded = jsonDecode(await response.readAsString()) as Map<String, Object?>;
      expect((decoded['result']! as Map)['tools'], isNotEmpty);
    });

    test('returns 204 for a notification', () async {
      final response = await mcpHttpHandler(_server())(
        _post(jsonEncode({'method': 'notifications/initialized'})),
      );
      expect(response.statusCode, 204);
    });

    test('rejects invalid JSON', () async {
      final response = await mcpHttpHandler(_server())(_post('{not json'));
      expect(response.statusCode, 400);
    });

    test('rejects a non-object body', () async {
      final response = await mcpHttpHandler(_server())(_post('[]'));
      expect(response.statusCode, 400);
    });

    test('enforces the bearer token when set', () async {
      final handler = mcpHttpHandler(_server(), token: 'secret');
      final denied = await handler(_post(jsonEncode({'id': 1, 'method': 'ping'})));
      expect(denied.statusCode, 403);
      final allowed = await handler(
        _post(jsonEncode({'id': 1, 'method': 'ping'}), headers: {'authorization': 'Bearer secret'}),
      );
      expect(allowed.statusCode, 200);
    });

    test('reports liveness on /healthz', () async {
      final response = await mcpHttpHandler(
        _server(),
      )(Request('GET', Uri.parse('http://localhost/healthz')));
      expect(response.statusCode, 200);
    });

    test('serves an instruction page on / listing the tools and the endpoint', () async {
      final response = await mcpHttpHandler(
        _server(),
      )(Request('GET', Uri.parse('http://localhost/')));
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('text/html'));
      final body = await response.readAsString();
      expect(body, contains('/mcp'));
      expect(body, contains('echo'), reason: 'lists the registered tools');
      expect(body, contains('docs.fluvie.dev'));
    });

    test('the instruction page notes the bearer token only when one is set', () async {
      final open = await mcpHttpHandler(
        _server(),
      )(Request('GET', Uri.parse('http://localhost/')));
      expect(await open.readAsString(), isNot(contains('Authorization: Bearer')));

      final guarded = await mcpHttpHandler(_server(), token: 'secret')(
        Request('GET', Uri.parse('http://localhost/')),
      );
      expect(await guarded.readAsString(), contains('Authorization: Bearer'));
    });
  });
}
