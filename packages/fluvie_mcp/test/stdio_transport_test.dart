import 'dart:convert';

import 'package:fluvie_mcp/fluvie_mcp.dart';
import 'package:test/test.dart';

McpServer _server() => McpServer(name: 'fluvie', version: '0.1.0', tools: const <McpTool>[]);

void main() {
  group('processStdioLine', () {
    test('returns a response for a request', () async {
      final line = await processStdioLine(_server(), jsonEncode({'id': 1, 'method': 'ping'}));
      expect(jsonDecode(line!), containsPair('id', 1));
    });

    test('returns null for blank, garbage, and non-object lines', () async {
      final server = _server();
      expect(await processStdioLine(server, '   '), isNull);
      expect(await processStdioLine(server, 'not json'), isNull);
      expect(await processStdioLine(server, '[]'), isNull);
      expect(await processStdioLine(server, jsonEncode({'method': 'notifications/x'})), isNull);
    });
  });

  group('serveStdio', () {
    test('writes one response line per request line, skipping notifications', () async {
      final input = Stream<List<int>>.fromIterable([
        utf8.encode('${jsonEncode({'id': 1, 'method': 'ping'})}\n'),
        utf8.encode('${jsonEncode({'method': 'notifications/x'})}\n'),
        utf8.encode('${jsonEncode({'id': 2, 'method': 'ping'})}\n'),
      ]);
      final output = StringBuffer();

      await serveStdio(_server(), input: input, output: output);

      final lines = const LineSplitter().convert(output.toString());
      expect(lines, hasLength(2));
      expect(jsonDecode(lines.first), containsPair('id', 1));
      expect(jsonDecode(lines.last), containsPair('id', 2));
    });
  });
}
