import 'dart:convert' show utf8;

import 'package:fluvie/src/rendering/encoding/content_hash.dart' show fnv1a64Hex;
import 'package:markdown/markdown.dart' as md;

/// The process-lifetime memo of `source -> AST`, keyed by the in-house
/// [fnv1a64Hex] content hash.
final Map<String, List<md.Node>> _cache = {};

/// Parses [source] to a `markdown` package AST once and caches it by content
/// hash.
///
/// The parse runs at most once per [source] — frame N never re-parses — and two
/// `Markdown` widgets with the same source share one AST. `markdown` is the
/// standard CommonMark parser; parsing to a [md.Node] tree is a pure transform
/// (no IO, clock, or randomness), so given the pinned dep the AST is
/// byte-identical across machines and re-renders. The GitHub-flavored extension
/// set is pinned so tables and fenced blocks parse the same everywhere.
///
/// The cache is content-addressed, so it is render-order-independent: the same
/// key always returns the same (identical) node list. An empty source yields an
/// empty list. The returned list is unmodifiable so callers cannot mutate the
/// cached entry.
List<md.Node> parseMarkdownCached(String source) {
  final key = fnv1a64Hex(utf8.encode(source));
  return _cache.putIfAbsent(key, () => List<md.Node>.unmodifiable(_parse(source)));
}

/// Parses [source] with the pinned GitHub-flavored extension set; an empty
/// source short-circuits to an empty list before touching the parser.
List<md.Node> _parse(String source) {
  if (source.isEmpty) return const [];
  return md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
  ).parseLines(source.split('\n'));
}

/// Clears the markdown parse cache. Test-only: production never evicts (the memo
/// is pure), but tests assert miss-then-hit behaviour from a clean slate.
void clearMarkdownCache() => _cache.clear();
