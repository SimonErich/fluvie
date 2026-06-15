// WI-7 (D-Files): the pure code layout splitter. `layoutCodeLines` breaks the
// highlighted spans into per-line tokens, records each run's joined-source start
// offset, and counts each line's length including its newline so the counts sum
// to the joined length.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/elements/code/highlight/highlight_span.dart';
import 'package:fluvie/src/elements/code/highlight/token_style.dart';
import 'package:fluvie/src/elements/code/render/code_layout.dart';

void main() {
  group('HighlightSpan diagnostics', () {
    test('toString names its length and style; equal spans share a hash', () {
      const span = HighlightSpan('void', TokenStyle.keyword);
      expect(span.toString(), contains('4 chars'));
      expect(span.toString(), contains('keyword'));
      // A distinct runtime instance with equal value (the runtime substring
      // defeats const-canonicalization): equal value implies equal hashCode.
      final other = HighlightSpan('void'.substring(0), TokenStyle.keyword);
      expect(identical(span, other), isFalse);
      expect(span, other);
      expect(span.hashCode, other.hashCode);
    });
  });

  group('layoutCodeLines', () {
    test('a single line yields one line of its tokens', () {
      final lines = layoutCodeLines(const [
        HighlightSpan('void', TokenStyle.keyword),
        HighlightSpan(' main', TokenStyle.function),
      ]);
      expect(lines, hasLength(1));
      expect(lines.first.number, 1);
      expect(lines.first.tokens.map((t) => t.text).join(), 'void main');
      expect(lines.first.length, 'void main'.length);
    });

    test('splits on newlines into numbered lines', () {
      final lines = layoutCodeLines(const [HighlightSpan('a\nbb\nccc', TokenStyle.plain)]);
      expect(lines.map((l) => l.number), [1, 2, 3]);
      expect(lines.map((l) => l.tokens.single.text), ['a', 'bb', 'ccc']);
      // lines 1 and 2 include their trailing newline; the last does not.
      expect(lines.map((l) => l.length), [2, 3, 3]);
    });

    test('the line lengths sum to the joined source length', () {
      const source = 'one\ntwo\nthree';
      final lines = layoutCodeLines(const [HighlightSpan(source, TokenStyle.plain)]);
      expect(lines.fold<int>(0, (sum, l) => sum + l.length), source.length);
    });

    test('records each token start offset within the joined source', () {
      final lines = layoutCodeLines(const [
        HighlightSpan('ab', TokenStyle.plain),
        HighlightSpan('\ncd', TokenStyle.keyword),
      ]);
      expect(lines.first.tokens.single.start, 0);
      // line 2 token 'cd' starts after 'ab' (2) + newline (1) = offset 3.
      expect(lines[1].tokens.single.start, 3);
    });

    test('an empty span list yields a single empty line', () {
      final lines = layoutCodeLines(const []);
      expect(lines, hasLength(1));
      expect(lines.first.tokens, isEmpty);
      expect(lines.first.length, 0);
    });

    test('a trailing newline yields a final empty line', () {
      final lines = layoutCodeLines(const [HighlightSpan('x\n', TokenStyle.plain)]);
      expect(lines, hasLength(2));
      expect(lines.last.tokens, isEmpty);
    });
  });

  group('CodeToken value equality', () {
    test('is value-equal by field with a stable hashCode', () {
      const a = CodeToken(text: 'x', style: TokenStyle.plain, start: 0);
      const b = CodeToken(text: 'x', style: TokenStyle.plain, start: 0);
      const c = CodeToken(text: 'x', style: TokenStyle.keyword, start: 0);
      const d = CodeToken(text: 'x', style: TokenStyle.plain, start: 1);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(a, isNot(d));
    });
  });
}
