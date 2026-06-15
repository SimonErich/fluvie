import 'dart:convert' show utf8;

import 'package:fluvie/src/elements/code/highlight/highlight_span.dart';
import 'package:fluvie/src/elements/code/highlight/syntax_highlighter.dart';
import 'package:fluvie/src/rendering/encoding/content_hash.dart' show fnv1a64Hex;

/// The process-lifetime memo of `(source, language) -> spans`, keyed by the
/// in-house [fnv1a64Hex] content hash.
final Map<String, List<HighlightSpan>> _cache = {};

/// The NUL byte used to join the cache-key parts. It cannot appear in source
/// code, a type name, or a language id, so distinct `(highlighter, language,
/// source)` triples never collapse onto the same key.
final String _keySeparator = String.fromCharCode(0);

/// The highlighted spans for [source] in [language], parsed once and cached by
/// content hash.
///
/// The highlight runs at most once per `(highlighter, source, language)` — frame
/// N never re-parses — and two `Code` widgets with the same source share one
/// parse. The cache is content-addressed, so it is render-order-independent and
/// never breaks the determinism contract: the same key always returns the same
/// (identical) value. On a miss [highlighter] tokenizes and the result is
/// stored; the returned list is unmodifiable so callers cannot mutate the entry.
List<HighlightSpan> highlightCached(
  String source,
  String language,
  SyntaxHighlighter highlighter,
) {
  final key = _key(source, language, highlighter);
  return _cache.putIfAbsent(
    key,
    () => List<HighlightSpan>.unmodifiable(highlighter.highlight(source, language)),
  );
}

/// The cache key for [source] in [language] under [highlighter].
///
/// The highlighter type, language, and source are joined by [_keySeparator] (a
/// NUL byte), which cannot appear in a type name or a language id, so
/// `('go lang', 'x')` never aliases `('go', 'lang x')`. The highlighter's
/// runtime type is part of the key too, so two `SyntaxHighlighter`
/// implementations with the same source and language never return each other's
/// spans.
String _key(String source, String language, SyntaxHighlighter highlighter) => fnv1a64Hex(
  utf8.encode(
    '${highlighter.runtimeType}$_keySeparator$language$_keySeparator$source',
  ),
);

/// Clears the highlight cache. Test-only: production never evicts (the memo is
/// pure), but tests assert miss-then-hit behaviour from a clean slate.
void clearHighlightCache() => _cache.clear();
