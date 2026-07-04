import 'package:fluvie_server/src/docs/doc_search_service.dart';
import 'package:test/test.dart';

import 'fakes/fake_doc_repository.dart';

void main() {
  late DocSearchService docs;

  setUp(() => docs = DocSearchService.fromRepository(FakeDocRepository.sample()));

  test('lists every page as path + title', () {
    final paths = docs.list().map((e) => e.path).toList();

    expect(docs.length, 3);
    expect(paths, contains('guides/ai-and-mcp.md'));
  });

  test('gets a page by path', () {
    expect(docs.get('guides/ai-and-mcp.md')?.title, 'AI and MCP');
  });

  test('returns null for an unknown path', () {
    expect(docs.get('nope.md'), isNull);
  });

  test('searches and returns hits with a matching snippet', () {
    final hits = docs.search('captions');

    expect(hits.first.path, 'guides/audio-and-captions.md');
    expect(hits.first.snippet.toLowerCase(), contains('captions'));
  });

  test('snippets fall back to the start of the page', () {
    // "Fluvie" appears at the very start of several pages.
    final hits = docs.search('fluvie');

    expect(hits, isNotEmpty);
    expect(hits.first.snippet, isNotEmpty);
  });
}
