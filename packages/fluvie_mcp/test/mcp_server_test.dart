import 'package:fluvie_mcp/fluvie_mcp.dart';
import 'package:test/test.dart';

McpServer _server() => McpServer(
  name: 'fluvie',
  version: '0.1.0',
  tools: [
    McpTool(
      name: 'echo',
      description: 'Echoes text.',
      inputSchema: const {'type': 'object'},
      handler: (args) async => McpToolResult.text('${args['text']}'),
    ),
    McpTool(
      name: 'boom',
      description: 'Throws.',
      inputSchema: const {'type': 'object'},
      handler: (args) async => throw StateError('kaboom'),
    ),
  ],
);

void main() {
  group('McpServer.handle', () {
    test('initialize echoes the client protocol version and reports the server', () async {
      final response = await _server().handle({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {'protocolVersion': '2025-03-26'},
      });
      expect(response!['id'], 1);
      final result = response['result']! as Map<String, Object?>;
      expect(result['protocolVersion'], '2025-03-26');
      expect((result['capabilities']! as Map).containsKey('tools'), isTrue);
      expect((result['serverInfo']! as Map)['name'], 'fluvie');
    });

    test('initialize falls back to the default protocol version', () async {
      final response = await _server().handle({'id': 2, 'method': 'initialize'});
      final result = response!['result']! as Map<String, Object?>;
      expect(result['protocolVersion'], defaultMcpProtocolVersion);
    });

    test('ping returns an empty result', () async {
      final response = await _server().handle({'id': 3, 'method': 'ping'});
      expect(response!['result'], <String, Object?>{});
    });

    test('tools/list lists registered tools', () async {
      final response = await _server().handle({'id': 4, 'method': 'tools/list'});
      final tools = (response!['result']! as Map)['tools']! as List;
      expect(tools.map((t) => (t! as Map)['name']), containsAll(['echo', 'boom']));
    });

    test('tools/call runs the handler', () async {
      final response = await _server().handle({
        'id': 5,
        'method': 'tools/call',
        'params': {
          'name': 'echo',
          'arguments': {'text': 'hi'},
        },
      });
      final result = response!['result']! as Map<String, Object?>;
      expect(result['isError'], isFalse);
      expect(((result['content']! as List).first! as Map)['text'], 'hi');
    });

    test('tools/call wraps handler errors as an isError result', () async {
      final response = await _server().handle({
        'id': 6,
        'method': 'tools/call',
        'params': {'name': 'boom', 'arguments': <String, Object?>{}},
      });
      final result = response!['result']! as Map<String, Object?>;
      expect(result['isError'], isTrue);
      expect(((result['content']! as List).first! as Map)['text'], contains('kaboom'));
    });

    test('tools/call defaults missing arguments to an empty map', () async {
      final response = await _server().handle({
        'id': 7,
        'method': 'tools/call',
        'params': {'name': 'echo'},
      });
      final result = response!['result']! as Map<String, Object?>;
      expect(((result['content']! as List).first! as Map)['text'], 'null');
    });

    test('tools/call with an unknown tool is an invalid-params error', () async {
      final response = await _server().handle({
        'id': 8,
        'method': 'tools/call',
        'params': {'name': 'nope'},
      });
      expect((response!['error']! as Map)['code'], jsonRpcInvalidParams);
    });

    test('tools/call with non-map params is an invalid-params error', () async {
      final response = await _server().handle({'id': 9, 'method': 'tools/call', 'params': 'x'});
      expect((response!['error']! as Map)['code'], jsonRpcInvalidParams);
    });

    test('an unknown method is method-not-found', () async {
      final response = await _server().handle({'id': 10, 'method': 'frob'});
      expect((response!['error']! as Map)['code'], jsonRpcMethodNotFound);
    });

    test('notifications and unknown notifications return null', () async {
      expect(await _server().handle({'method': 'notifications/initialized'}), isNull);
      expect(await _server().handle({'method': 'frob'}), isNull);
    });

    test('a request with no method is an invalid request', () async {
      final response = await _server().handle({'id': 11});
      expect((response!['error']! as Map)['code'], jsonRpcInvalidRequest);
    });

    test('a message with no method and no id returns null', () async {
      expect(await _server().handle(<String, Object?>{}), isNull);
    });

    test('exposes its registered tools', () {
      expect(_server().tools.map((t) => t.name), ['echo', 'boom']);
    });
  });
}
