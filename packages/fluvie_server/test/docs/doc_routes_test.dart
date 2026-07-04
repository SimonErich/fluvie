import 'dart:convert';

import 'package:fluvie_server/src/docs/doc_routes.dart';
import 'package:fluvie_server/src/docs/doc_search_service.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'fakes/fake_doc_repository.dart';

void main() {
  late Handler handler;

  setUp(() {
    final docs = DocSearchService.fromRepository(FakeDocRepository.sample());
    handler = docRoutes(docs);
  });

  Future<(int, Object?)> call(String path) async {
    final response = await handler(Request('GET', Uri.parse('http://localhost$path')));
    final body = await response.readAsString();
    return (response.statusCode, body.isEmpty ? null : jsonDecode(body));
  }

  test('GET /v1/docs lists the pages', () async {
    final (status, body) = await call('/v1/docs');

    expect(status, 200);
    expect((body! as Map)['pages'] as List, hasLength(3));
  });

  test('GET /v1/docs/search returns ranked results', () async {
    final (status, body) = await call('/v1/docs/search?q=captions');

    expect(status, 200);
    expect(
      (((body! as Map)['results'] as List).first as Map)['path'],
      'guides/audio-and-captions.md',
    );
  });

  test('GET /v1/docs/search requires q', () async {
    final (status, _) = await call('/v1/docs/search');

    expect(status, 400);
  });

  test('GET /v1/docs/get returns the page content', () async {
    final (status, body) = await call('/v1/docs/get?path=guides/ai-and-mcp.md');

    expect(status, 200);
    expect((body! as Map)['content'], contains('# AI and MCP'));
  });

  test('GET /v1/docs/get requires path', () async {
    final (status, _) = await call('/v1/docs/get');

    expect(status, 400);
  });

  test('GET /v1/docs/get is 404 for an unknown page', () async {
    final (status, _) = await call('/v1/docs/get?path=missing.md');

    expect(status, 404);
  });
}
