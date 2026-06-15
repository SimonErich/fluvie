// WI-5 (D-Highlight/D-HighlightSeam/D-Cache): the SyntaxHighlighter contract,
// the highlight.js-backed impl, and the content-hashed cache. The highlighter is
// a pure function of (source, language): lossless, deterministic, cached once.
// NO goldens.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/elements/code/highlight/highlight_cache.dart';
import 'package:fluvie/src/elements/code/highlight/highlight_js_highlighter.dart';
import 'package:fluvie/src/elements/code/highlight/highlight_span.dart';
import 'package:fluvie/src/elements/code/highlight/syntax_highlighter.dart';
import 'package:fluvie/src/elements/code/highlight/token_style.dart';

const _dart = '''
// a comment
void main() {
  final x = 42;
  print('hi');
}
''';

String _joined(List<HighlightSpan> spans) => spans.map((s) => s.text).join();

/// A second [SyntaxHighlighter] that classifies the whole source as one plain
/// span, used to prove the cache keys on the highlighter identity.
final class _PlainHighlighter implements SyntaxHighlighter {
  const _PlainHighlighter();

  @override
  List<HighlightSpan> highlight(String source, String language) => [
    HighlightSpan(source, TokenStyle.plain),
  ];
}

Set<TokenStyle> _stylesOf(List<HighlightSpan> spans, bool Function(String) match) => {
  for (final s in spans)
    if (match(s.text)) s.style,
};

void main() {
  const highlighter = HighlightJsHighlighter();

  group('HighlightJsHighlighter contract', () {
    test('is a SyntaxHighlighter', () {
      expect(highlighter, isA<SyntaxHighlighter>());
    });

    test('concatenated span text equals the source (lossless)', () {
      final spans = highlighter.highlight(_dart, 'dart');
      expect(_joined(spans), _dart);
    });

    test('classifies keywords', () {
      final spans = highlighter.highlight(_dart, 'dart');
      expect(_stylesOf(spans, (t) => t == 'void'), contains(TokenStyle.keyword));
    });

    test('classifies strings including quotes', () {
      final spans = highlighter.highlight(_dart, 'dart');
      final stringSpans = [
        for (final s in spans)
          if (s.style == TokenStyle.string) s.text,
      ];
      expect(stringSpans.any((t) => t.contains("'hi'")), isTrue);
    });

    test('classifies comments', () {
      final spans = highlighter.highlight(_dart, 'dart');
      final commentSpans = [
        for (final s in spans)
          if (s.style == TokenStyle.comment) s.text,
      ];
      expect(commentSpans.any((t) => t.contains('a comment')), isTrue);
    });

    test('classifies numbers', () {
      final spans = highlighter.highlight(_dart, 'dart');
      expect(_stylesOf(spans, (t) => t.trim() == '42'), contains(TokenStyle.number));
    });

    test('classifies a class name as a type', () {
      final spans = highlighter.highlight('class Foo {}', 'dart');
      final typeText = [
        for (final s in spans)
          if (s.style == TokenStyle.type) s.text,
      ].join();
      expect(typeText, contains('Foo'));
    });

    test('an unknown language falls back to a single plain span (no throw)', () {
      final spans = highlighter.highlight('anything at all\n', 'no-such-lang');
      expect(spans, hasLength(1));
      expect(spans.single.style, TokenStyle.plain);
      expect(spans.single.text, 'anything at all\n');
    });

    test('empty source yields an empty span list', () {
      expect(highlighter.highlight('', 'dart'), isEmpty);
    });

    test('identical input returns an equal span list (determinism proof)', () {
      final a = highlighter.highlight(_dart, 'dart');
      final b = highlighter.highlight(_dart, 'dart');
      expect(a, b);
    });

    test('highlights python and javascript without throwing', () {
      expect(
        _joined(highlighter.highlight('def f():\n    return 1\n', 'python')),
        'def f():\n    return 1\n',
      );
      expect(
        _joined(highlighter.highlight("const x = 'hi';\n", 'javascript')),
        "const x = 'hi';\n",
      );
    });
  });

  group('highlightCached (content-hashed memo)', () {
    setUp(clearHighlightCache);

    test('returns the same instance on the second call', () {
      final first = highlightCached(_dart, 'dart', highlighter);
      final second = highlightCached(_dart, 'dart', highlighter);
      expect(identical(first, second), isTrue);
    });

    test('different source produces a different (non-identical) result', () {
      final a = highlightCached('void a() {}', 'dart', highlighter);
      final b = highlightCached('void b() {}', 'dart', highlighter);
      expect(identical(a, b), isFalse);
    });

    test('different language re-keys the cache', () {
      final a = highlightCached("x = 'hi'", 'python', highlighter);
      final b = highlightCached("x = 'hi'", 'dart', highlighter);
      expect(identical(a, b), isFalse);
    });

    test('the cached result is lossless', () {
      expect(_joined(highlightCached(_dart, 'dart', highlighter)), _dart);
    });

    test('a different highlighter re-keys the cache (identity is part of the key)', () {
      const plain = _PlainHighlighter();
      final viaJs = highlightCached('class Foo {}', 'dart', highlighter);
      final viaPlain = highlightCached('class Foo {}', 'dart', plain);
      expect(identical(viaJs, viaPlain), isFalse);
      // The plain highlighter must return ITS spans, not the highlight.js entry.
      expect(viaPlain.single.style, TokenStyle.plain);
      expect(viaPlain.single.text, 'class Foo {}');
    });

    test('the NUL separator stops a language/source delimiter collision', () {
      const plain = _PlainHighlighter();
      // Without a NUL delimiter, ('go lang','x') and ('go','lang x') would join
      // to the same string and alias. They must stay distinct entries.
      final a = highlightCached('x', 'go lang', plain);
      final b = highlightCached('lang x', 'go', plain);
      expect(identical(a, b), isFalse);
      expect(a.single.text, 'x');
      expect(b.single.text, 'lang x');
    });
  });
}
