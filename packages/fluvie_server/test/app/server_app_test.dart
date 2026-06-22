import 'dart:convert';

import 'package:fluvie_server/src/app/server_app.dart';
import 'package:fluvie_server/src/app/server_tools.dart';
import 'package:fluvie_server/src/config/mcp_mode.dart';
import 'package:fluvie_server/src/docs/doc_search_service.dart';
import 'package:fluvie_server/src/mcp/mcp_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../docs/fake_doc_repository.dart';
import '../support/test_deps.dart';

void main() {
  DocSearchService sampleDocs() => DocSearchService.fromRepository(FakeDocRepository.sample());

  McpServer docsMcp(DocSearchService docs) => McpServer(
    name: 'fluvie',
    version: 't',
    tools: buildServerTools(mode: McpMode.docs, docs: docs),
  );

  Future<Response> get(Handler app, String path, {Map<String, String>? headers}) async =>
      app(Request('GET', Uri.parse('http://localhost$path'), headers: headers));

  Future<Response> postMcp(Handler app, {Map<String, String>? headers}) async => app(
    Request(
      'POST',
      Uri.parse('http://localhost/mcp'),
      headers: {'content-type': 'application/json', ...?headers},
      body: jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': 'tools/list'}),
    ),
  );

  Future<Response> postValidate(Handler app, String code, {Map<String, String>? headers}) async =>
      app(
        Request(
          'POST',
          Uri.parse('http://localhost/v1/validate'),
          headers: {'content-type': 'application/json', ...?headers},
          body: jsonEncode({'code': code}),
        ),
      );

  group('the full server (API + MCP + docs)', () {
    late Handler app;

    setUp(() {
      final docs = sampleDocs();
      app = buildServerApp(
        api: inMemoryDeps(schemaJson: '{"type":"object"}'),
        mcp: docsMcp(docs),
        docs: docs,
      );
    });

    test('serves the unified landing page at /', () async {
      final response = await get(app, '/');

      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('text/html'));
    });

    test('serves health probes', () async {
      expect((await get(app, '/healthz')).statusCode, 200);
      expect((await get(app, '/readyz')).statusCode, 200);
    });

    test('serves the docs HTTP mirror', () async {
      expect((await get(app, '/v1/docs')).statusCode, 200);
    });

    test('serves the render API schema route', () async {
      expect((await get(app, '/v1/schema/video-spec')).statusCode, 200);
    });

    test('serves the MCP endpoint', () async {
      final response = await postMcp(app);
      final decoded = jsonDecode(await response.readAsString()) as Map<String, Object?>;

      expect(response.statusCode, 200);
      expect((decoded['result']! as Map)['tools'], isNotEmpty);
    });

    test('validates submitted code with a bearer token', () async {
      final response = await postValidate(
        app,
        'Video build() => Video(scenes: []);',
        headers: {'authorization': 'Bearer tok'},
      );
      final decoded = jsonDecode(await response.readAsString()) as Map<String, Object?>;

      expect(response.statusCode, 200);
      expect(decoded['ok'], isTrue);
      expect(decoded['diagnostics'], isEmpty);
    });
  });

  group('a docs-only server', () {
    late Handler app;

    setUp(() => app = buildServerApp(docs: sampleDocs()));

    test('serves docs', () async {
      expect((await get(app, '/v1/docs')).statusCode, 200);
    });

    test('serves the landing page', () async {
      expect((await get(app, '/')).statusCode, 200);
    });

    test('has no render API', () async {
      expect((await get(app, '/v1/renders/abc')).statusCode, 404);
    });

    test('has no validate route', () async {
      expect((await postValidate(app, 'x')).statusCode, 404);
    });
  });

  group('MCP token', () {
    late Handler app;

    setUp(() {
      final docs = sampleDocs();
      app = buildServerApp(mcp: docsMcp(docs), docs: docs, mcpToken: 'secret');
    });

    test('rejects an unauthenticated /mcp call', () async {
      expect((await postMcp(app)).statusCode, 403);
    });

    test('accepts the bearer token', () async {
      final response = await postMcp(app, headers: {'authorization': 'Bearer secret'});

      expect(response.statusCode, 200);
    });
  });
}
