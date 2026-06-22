import 'dart:math' as math;

import 'package:fluvie_server/src/docs/doc_page.dart';

/// A ranked search hit: the page path and its BM25 relevance score.
typedef DocRank = ({String path, double score});

/// An in-memory BM25 full-text index over the documentation corpus.
///
/// Built once at startup; ranking is pure and deterministic (ties break by path)
/// so the same query always returns the same order. No embeddings, no network —
/// the corpus is small and the MCP client supplies the semantic reasoning.
final class DocIndex {
  /// Builds the index over [pages].
  DocIndex(List<DocPage> pages) {
    _docCount = pages.length;
    var totalLength = 0;
    for (final page in pages) {
      final tokens = _tokenize('${page.title} ${page.body}');
      final freqs = <String, int>{};
      for (final token in tokens) {
        freqs[token] = (freqs[token] ?? 0) + 1;
      }
      _termFreqs.add(freqs);
      _lengths.add(tokens.length);
      _paths.add(page.path);
      totalLength += tokens.length;
      for (final term in freqs.keys) {
        _docFreq[term] = (_docFreq[term] ?? 0) + 1;
      }
    }
    _avgLength = _docCount == 0 ? 0 : totalLength / _docCount;
  }

  static const double _k1 = 1.5;
  static const double _b = 0.75;

  final List<Map<String, int>> _termFreqs = [];
  final List<int> _lengths = [];
  final List<String> _paths = [];
  final Map<String, int> _docFreq = {};
  late final int _docCount;
  late final double _avgLength;

  /// Ranks the corpus against [query], returning up to [limit] hits with a
  /// positive score, best first (ties broken by path for stable output).
  List<DocRank> rank(String query, {int limit = 5}) {
    final terms = _tokenize(query).toSet();
    if (terms.isEmpty || _docCount == 0) return const [];

    final hits = <DocRank>[];
    for (var doc = 0; doc < _docCount; doc++) {
      final score = _score(doc, terms);
      if (score > 0) hits.add((path: _paths[doc], score: score));
    }
    hits.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.path.compareTo(b.path);
    });
    return hits.length > limit ? hits.sublist(0, limit) : hits;
  }

  double _score(int doc, Set<String> terms) {
    final freqs = _termFreqs[doc];
    final dl = _lengths[doc];
    var score = 0.0;
    for (final term in terms) {
      final tf = freqs[term];
      if (tf == null) continue;
      final df = _docFreq[term]!;
      final idf = math.log(1 + (_docCount - df + 0.5) / (df + 0.5));
      final norm = tf * (_k1 + 1) / (tf + _k1 * (1 - _b + _b * dl / _avgLength));
      score += idf * norm;
    }
    return score;
  }

  static final RegExp _word = RegExp('[a-z0-9]+');

  static List<String> _tokenize(String text) =>
      _word.allMatches(text.toLowerCase()).map((m) => m[0]!).toList();
}
