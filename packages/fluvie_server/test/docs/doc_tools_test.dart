import 'dart:convert';

import 'package:fluvie_server/src/docs/doc_search_service.dart';
import 'package:fluvie_server/src/docs/doc_tools.dart';
import 'package:fluvie_server/src/mcp/mcp_tool.dart';
import 'package:test/test.dart';

import 'fake_doc_repository.dart';

void main() {
  late Map<String, McpTool> tools;

  setUp(() {
    final docs = DocSearchService.fromRepository(FakeDocRepository.sample());
    tools = {for (final tool in buildDocTools(docs)) tool.name: tool};
  });

  String text(McpToolResult result) => result.content.single['text']! as String;

  test('exposes list_docs, search_docs, and get_doc', () {
    expect(tools.keys, containsAll(['list_docs', 'search_docs', 'get_doc']));
  });

  test('list_docs returns every page', () async {
    final result = await tools['list_docs']!.handler(const {});
    final pages = jsonDecode(text(result)) as List;

    expect(pages, hasLength(3));
  });

  test('search_docs returns ranked matches', () async {
    final result = await tools['search_docs']!.handler(const {'query': 'mcp prompt'});
    final hits = jsonDecode(text(result)) as List;

    expect((hits.first as Map)['path'], 'guides/ai-and-mcp.md');
  });

  test('search_docs honours a string limit', () async {
    final result = await tools['search_docs']!.handler(const {'query': 'fluvie', 'limit': '1'});
    final hits = jsonDecode(text(result)) as List;

    expect(hits, hasLength(1));
  });

  test('search_docs rejects a missing query', () {
    expect(
      () => tools['search_docs']!.handler(const {}),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('get_doc returns the full page body', () async {
    final result = await tools['get_doc']!.handler(const {'path': 'guides/ai-and-mcp.md'});

    expect(text(result), contains('# AI and MCP'));
    expect(result.isError, isFalse);
  });

  test('get_doc reports an unknown path as an error', () async {
    final result = await tools['get_doc']!.handler(const {'path': '../secrets'});

    expect(result.isError, isTrue);
  });

  test('get_doc rejects a missing path', () {
    expect(
      () => tools['get_doc']!.handler(const {}),
      throwsA(isA<ArgumentError>()),
    );
  });
}
