// WI-3 (D-Theme): the tokenized code model and the CodeTheme value type.
// `TokenStyle` enumerates the highlight kinds; `HighlightSpan` is a value-equal
// (text, style) pair; `CodeTheme` maps every TokenStyle to a color and carries
// the editor chrome colors, value-equal by field.

import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/elements/code/highlight/highlight_span.dart';
import 'package:fluvie/src/elements/code/highlight/token_style.dart';
import 'package:fluvie/src/elements/code/theme/code_theme.dart';

void main() {
  group('TokenStyle', () {
    test('enumerates the highlight kinds', () {
      expect(TokenStyle.values, <TokenStyle>[
        TokenStyle.keyword,
        TokenStyle.string,
        TokenStyle.comment,
        TokenStyle.number,
        TokenStyle.type,
        TokenStyle.function,
        TokenStyle.punctuation,
        TokenStyle.plain,
      ]);
    });
  });

  group('HighlightSpan', () {
    test('carries its text and style', () {
      const span = HighlightSpan('void', TokenStyle.keyword);
      expect(span.text, 'void');
      expect(span.style, TokenStyle.keyword);
    });

    test('is value-equal by field', () {
      const a = HighlightSpan('x', TokenStyle.plain);
      const b = HighlightSpan('x', TokenStyle.plain);
      const c = HighlightSpan('x', TokenStyle.number);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  group('CodeTheme.dark / .light', () {
    test('dark maps every TokenStyle to a non-null color', () {
      const theme = CodeTheme.dark();
      for (final style in TokenStyle.values) {
        expect(theme.colorFor(style), isA<Color>());
      }
    });

    test('light maps every TokenStyle to a non-null color', () {
      const theme = CodeTheme.light();
      for (final style in TokenStyle.values) {
        expect(theme.colorFor(style), isA<Color>());
      }
    });

    test('colorFor returns the per-style color', () {
      const theme = CodeTheme.dark();
      expect(theme.colorFor(TokenStyle.keyword), theme.keyword);
      expect(theme.colorFor(TokenStyle.string), theme.string);
      expect(theme.colorFor(TokenStyle.comment), theme.comment);
      expect(theme.colorFor(TokenStyle.number), theme.number);
      expect(theme.colorFor(TokenStyle.type), theme.type);
      expect(theme.colorFor(TokenStyle.function), theme.function);
      expect(theme.colorFor(TokenStyle.punctuation), theme.punctuation);
      expect(theme.colorFor(TokenStyle.plain), theme.plain);
    });

    test('carries the editor chrome colors and dim opacity', () {
      const theme = CodeTheme.dark();
      expect(theme.background, isA<Color>());
      expect(theme.gutterColor, isA<Color>());
      expect(theme.lineNumberColor, isA<Color>());
      expect(theme.highlightColor, isA<Color>());
      expect(theme.chromeColor, isA<Color>());
      expect(theme.dimOpacity, inInclusiveRange(0.0, 1.0));
    });

    test('carries red / green diff gutter colors', () {
      const dark = CodeTheme.dark();
      const light = CodeTheme.light();
      expect(dark.addedGutter, isA<Color>());
      expect(dark.removedGutter, isA<Color>());
      expect(light.addedGutter, isA<Color>());
      expect(light.removedGutter, isA<Color>());
      expect(dark.addedGutter, isNot(dark.removedGutter));
    });

    test('the diff gutters default when omitted from the main constructor', () {
      const custom = CodeTheme(
        keyword: Color(0xFF111111),
        string: Color(0xFF222222),
        comment: Color(0xFF333333),
        number: Color(0xFF444444),
        type: Color(0xFF555555),
        function: Color(0xFF666666),
        punctuation: Color(0xFF777777),
        plain: Color(0xFF888888),
        background: Color(0xFF000000),
        gutterColor: Color(0xFF999999),
        lineNumberColor: Color(0xFFAAAAAA),
        highlightColor: Color(0x22FFFFFF),
        chromeColor: Color(0xFFBBBBBB),
        dimOpacity: 0.4,
      );
      expect(custom.addedGutter, isA<Color>());
      expect(custom.removedGutter, isA<Color>());
    });

    test('a custom diff gutter is carried and value-equal', () {
      const a = CodeTheme.dark();
      const b = CodeTheme.dark();
      expect(a.addedGutter, b.addedGutter);
      expect(a, b);
    });

    test('dark and light differ', () {
      expect(const CodeTheme.dark(), isNot(const CodeTheme.light()));
    });

    test('is value-equal by field', () {
      expect(const CodeTheme.dark(), const CodeTheme.dark());
      expect(const CodeTheme.dark().hashCode, const CodeTheme.dark().hashCode);
    });

    test('a custom theme differs from the presets and is value-equal to its twin', () {
      const a = CodeTheme(
        keyword: Color(0xFF111111),
        string: Color(0xFF222222),
        comment: Color(0xFF333333),
        number: Color(0xFF444444),
        type: Color(0xFF555555),
        function: Color(0xFF666666),
        punctuation: Color(0xFF777777),
        plain: Color(0xFF888888),
        background: Color(0xFF000000),
        gutterColor: Color(0xFF999999),
        lineNumberColor: Color(0xFFAAAAAA),
        highlightColor: Color(0x22FFFFFF),
        chromeColor: Color(0xFFBBBBBB),
        dimOpacity: 0.4,
      );
      const b = CodeTheme(
        keyword: Color(0xFF111111),
        string: Color(0xFF222222),
        comment: Color(0xFF333333),
        number: Color(0xFF444444),
        type: Color(0xFF555555),
        function: Color(0xFF666666),
        punctuation: Color(0xFF777777),
        plain: Color(0xFF888888),
        background: Color(0xFF000000),
        gutterColor: Color(0xFF999999),
        lineNumberColor: Color(0xFFAAAAAA),
        highlightColor: Color(0x22FFFFFF),
        chromeColor: Color(0xFFBBBBBB),
        dimOpacity: 0.4,
      );
      expect(a, b);
      expect(a, isNot(const CodeTheme.dark()));
    });

    test('has a readable toString', () {
      expect(const CodeTheme.dark().toString(), contains('CodeTheme'));
    });
  });
}
