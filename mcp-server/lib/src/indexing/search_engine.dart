import 'dart:math';

import 'doc_indexer.dart';

/// Search result with relevance score
class SearchResult {
  final IndexedDocument document;
  final double score;
  final String snippet;

  const SearchResult({
    required this.document,
    required this.score,
    required this.snippet,
  });

  @override
  String toString() => 'SearchResult(${document.title}, score: $score)';
}

/// TF-IDF based search engine for documentation
class SearchEngine {
  static SearchEngine? _instance;
  static SearchEngine get instance => _instance ??= SearchEngine._();

  DocIndex? _index;
  Map<String, double> _idf = {};
  bool _initialized = false;

  SearchEngine._();

  /// Check if the engine is initialized
  bool get isInitialized => _initialized;

  /// Initialize the search engine with documents
  Future<void> initialize(String docsPath) async {
    final indexer = DocIndexer(docsPath: docsPath);
    _index = await indexer.buildIndex();
    _idf = _computeIdf();
    _initialized = true;
  }

  /// Compute Inverse Document Frequency for all terms
  Map<String, double> _computeIdf() {
    if (_index == null) return {};

    final docCount = _index!.documents.length;
    if (docCount == 0) return {};

    final idf = <String, double>{};
    final termDocCounts = <String, int>{};

    for (final doc in _index!.documents) {
      final terms = doc.keywords.toSet();
      for (final term in terms) {
        termDocCounts[term] = (termDocCounts[term] ?? 0) + 1;
      }
    }

    for (final entry in termDocCounts.entries) {
      idf[entry.key] = log(docCount / entry.value);
    }

    return idf;
  }

  /// Search documents with a query
  Future<List<SearchResult>> search({
    required String query,
    String category = 'all',
    int limit = 5,
  }) async {
    if (_index == null) {
      return [];
    }

    final queryTerms = _tokenize(query.toLowerCase());
    if (queryTerms.isEmpty) return [];

    final scores = <IndexedDocument, double>{};

    for (final doc in _index!.documents) {
      // Filter by category
      if (category != 'all' && doc.category != category) continue;

      double score = 0;
      for (final term in queryTerms) {
        final tf = _computeTf(term, doc.keywords);
        final idf = _idf[term] ?? 0;
        score += tf * idf;
      }

      // Boost title matches
      final queryLower = query.toLowerCase();
      if (doc.title.toLowerCase().contains(queryLower)) {
        score *= 2.5;
      }

      // Boost exact section matches
      for (final section in doc.sections) {
        if (section.toLowerCase().contains(queryLower)) {
          score *= 1.5;
          break;
        }
      }

      // Boost if query appears in first 500 chars (likely important content)
      if (doc.content
          .toLowerCase()
          .substring(
            0,
            min(500, doc.content.length),
          )
          .contains(queryLower)) {
        score *= 1.3;
      }

      if (score > 0) scores[doc] = score;
    }

    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(limit).map((e) {
      return SearchResult(
        document: e.key,
        score: e.value,
        snippet: _extractSnippet(e.key, queryTerms),
      );
    }).toList();
  }

  /// Tokenize text into words
  List<String> _tokenize(String text) {
    return text
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2)
        .toList();
  }

  /// Compute Term Frequency
  double _computeTf(String term, List<String> keywords) {
    if (keywords.isEmpty) return 0;
    final count = keywords.where((k) => k == term).length;
    return count / keywords.length;
  }

  /// Extract a relevant snippet from the document
  String _extractSnippet(IndexedDocument doc, List<String> queryTerms) {
    final content = doc.content;
    final lowerContent = content.toLowerCase();

    // Find the first occurrence of any query term
    int bestPos = -1;
    for (final term in queryTerms) {
      final pos = lowerContent.indexOf(term);
      if (pos != -1 && (bestPos == -1 || pos < bestPos)) {
        bestPos = pos;
      }
    }

    // If no term found, use the beginning
    if (bestPos == -1) {
      bestPos = 0;
    }

    // Extract context around the match
    const snippetLength = 200;
    final start = max(0, bestPos - 50);
    final end = min(content.length, start + snippetLength);

    var snippet = content.substring(start, end);

    // Clean up the snippet
    if (start > 0) snippet = '...$snippet';
    if (end < content.length) snippet = '$snippet...';

    return snippet.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Get document count
  int get documentCount => _index?.documents.length ?? 0;

  /// Get all categories
  Set<String> get categories => _index?.categories ?? {};
}
