import 'package:fluvie_server/src/docs/doc_index.dart';
import 'package:fluvie_server/src/docs/doc_page.dart';
import 'package:test/test.dart';

void main() {
  const corpus = FakeCorpus.sample;

  test('ranks the most relevant page first', () {
    final index = DocIndex(corpus);

    final hits = index.rank('mcp prompt');

    expect(hits.first.path, 'guides/ai-and-mcp.md');
  });

  test('returns nothing for a query with no matches', () {
    final index = DocIndex(corpus);

    expect(index.rank('quantum entanglement'), isEmpty);
  });

  test('returns nothing for an empty query', () {
    final index = DocIndex(corpus);

    expect(index.rank(''), isEmpty);
  });

  test('returns nothing for an empty corpus', () {
    expect(DocIndex(const []).rank('anything'), isEmpty);
  });

  test('respects the result limit', () {
    final index = DocIndex(corpus);

    expect(index.rank('fluvie', limit: 1).length, 1);
  });

  test('is deterministic across runs', () {
    final index = DocIndex(corpus);

    expect(index.rank('video captions'), index.rank('video captions'));
  });

  test('breaks score ties by path', () {
    final index = DocIndex(const [
      DocPage(path: 'b.md', title: 'b', body: 'unicorn'),
      DocPage(path: 'a.md', title: 'a', body: 'unicorn'),
    ]);

    expect(index.rank('unicorn').map((h) => h.path), ['a.md', 'b.md']);
  });
}

/// The shared sample corpus used across the docs tests.
abstract final class FakeCorpus {
  static const sample = [
    DocPage(
      path: 'guides/ai-and-mcp.md',
      title: 'AI and MCP',
      body:
          'Use the MCP server to author Fluvie videos from a prompt. '
          'The model emits a VideoSpec which the server renders.',
    ),
    DocPage(
      path: 'guides/audio-and-captions.md',
      title: 'Audio and captions',
      body:
          'Add an audio track and burned-in captions to a Fluvie video. '
          'Captions are timed to the beat.',
    ),
    DocPage(
      path: 'getting-started/installation.md',
      title: 'Installation',
      body: 'Install Fluvie and the CLI with dart pub, then provision ffmpeg.',
    ),
  ];
}
