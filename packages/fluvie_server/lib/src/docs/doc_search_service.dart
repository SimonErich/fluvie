import 'dart:math' as math;

import 'package:fluvie_server/src/docs/doc_index.dart';
import 'package:fluvie_server/src/docs/doc_page.dart';
import 'package:fluvie_server/src/docs/doc_repository.dart';

/// One entry in a documentation listing.
typedef DocListing = ({String path, String title});

/// One search result: where it is, what it is, and a matching excerpt.
typedef DocSearchHit = ({String path, String title, String snippet});

/// Searches and reads the documentation corpus.
///
/// Loads every page once via a [DocRepository], builds a [DocIndex], and answers
/// list/search/get. `get` only resolves paths in the loaded corpus, so a client
/// cannot read arbitrary files (no path traversal).
final class DocSearchService {
  DocSearchService._(this._byPath, this._index)
    : _listing = [
        for (final page in _byPath.values) (path: page.path, title: page.title),
      ];

  /// Loads the corpus from [repository] and builds the index.
  factory DocSearchService.fromRepository(DocRepository repository) {
    final pages = repository.load();
    return DocSearchService._({for (final page in pages) page.path: page}, DocIndex(pages));
  }

  final Map<String, DocPage> _byPath;
  final DocIndex _index;
  final List<DocListing> _listing;

  /// How many pages the corpus holds.
  int get length => _byPath.length;

  /// Every page as a `(path, title)` listing, in path order.
  List<DocListing> list() => _listing;

  /// The up-to-[limit] best matches for [query], each with a short excerpt.
  List<DocSearchHit> search(String query, {int limit = 5}) {
    return [
      for (final hit in _index.rank(query, limit: limit))
        (
          path: hit.path,
          title: _byPath[hit.path]!.title,
          snippet: _snippet(_byPath[hit.path]!.body, query),
        ),
    ];
  }

  /// The full page at [path], or `null` when it is not in the corpus.
  DocPage? get(String path) => _byPath[path];

  static final RegExp _word = RegExp('[a-z0-9]+');

  /// A ~240-char excerpt around the first query word found in [body], or the
  /// start of the page when none matches. Whitespace is collapsed onto one line.
  static String _snippet(String body, String query) {
    final collapsed = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    final lower = collapsed.toLowerCase();
    var at = -1;
    for (final match in _word.allMatches(query.toLowerCase())) {
      final found = lower.indexOf(match[0]!);
      if (found != -1 && (at == -1 || found < at)) at = found;
    }
    final start = at <= 40 ? 0 : at - 40;
    final end = math.min(start + 240, collapsed.length);
    final prefix = start > 0 ? '…' : '';
    final suffix = end < collapsed.length ? '…' : '';
    return '$prefix${collapsed.substring(start, end)}$suffix';
  }
}
