// WI-16 (D-Markdown/D-Cache): parse markdown to a `markdown` package AST once
// per content, cached by the in-house fnv1a64Hex content hash. The parse is a
// pure function of the source (no IO, clock, or randomness). NO goldens.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/elements/markdown/parse/markdown_parser.dart';
import 'package:markdown/markdown.dart' as md;

/// The first [md.Element] in [nodes], or `null` if the first node is text.
md.Element? _firstElement(List<md.Node> nodes) {
  for (final node in nodes) {
    if (node is md.Element) return node;
  }
  return null;
}

void main() {
  setUp(clearMarkdownCache);

  group('parseMarkdownCached node kinds', () {
    test('# H1 yields a heading node at level 1', () {
      final nodes = parseMarkdownCached('# Heading');
      final heading = _firstElement(nodes)!;
      expect(heading.tag, 'h1');
      expect(heading.textContent, 'Heading');
    });

    test('## H2 yields a heading node at level 2', () {
      final heading = _firstElement(parseMarkdownCached('## Sub'))!;
      expect(heading.tag, 'h2');
    });

    test('a dash list yields an unordered list with two items', () {
      final list = _firstElement(parseMarkdownCached('- a\n- b'))!;
      expect(list.tag, 'ul');
      expect(list.children!.whereType<md.Element>().map((e) => e.tag), ['li', 'li']);
    });

    test('a numbered list yields an ordered list', () {
      final list = _firstElement(parseMarkdownCached('1. one\n2. two'))!;
      expect(list.tag, 'ol');
      expect(list.children!.whereType<md.Element>(), hasLength(2));
    });

    test('a quote yields a blockquote node', () {
      final quote = _firstElement(parseMarkdownCached('> quoted'))!;
      expect(quote.tag, 'blockquote');
      expect(quote.textContent, contains('quoted'));
    });

    test('inline code yields a code node inside a paragraph', () {
      final paragraph = _firstElement(parseMarkdownCached('a `x` b'))!;
      final code = paragraph.children!.whereType<md.Element>().single;
      expect(code.tag, 'code');
      expect(code.textContent, 'x');
    });

    test('bold and italic yield strong and em nodes', () {
      final paragraph = _firstElement(parseMarkdownCached('**b** *i*'))!;
      final tags = paragraph.children!.whereType<md.Element>().map((e) => e.tag).toSet();
      expect(tags, containsAll(<String>['strong', 'em']));
    });

    test('a fenced block yields a pre>code node carrying its language', () {
      final pre = _firstElement(parseMarkdownCached('```dart\nvoid main() {}\n```'))!;
      expect(pre.tag, 'pre');
      final code = pre.children!.whereType<md.Element>().single;
      expect(code.tag, 'code');
      expect(code.attributes['class'], 'language-dart');
      expect(code.textContent.trim(), 'void main() {}');
    });

    test('an image yields an img node with its src and alt', () {
      final paragraph = _firstElement(parseMarkdownCached('![alt text](http://x/y.png)'))!;
      final img = paragraph.children!.whereType<md.Element>().single;
      expect(img.tag, 'img');
      expect(img.attributes['src'], 'http://x/y.png');
      expect(img.attributes['alt'], 'alt text');
    });

    test('a plain paragraph yields a p node with its text', () {
      final paragraph = _firstElement(parseMarkdownCached('just words'))!;
      expect(paragraph.tag, 'p');
      expect(paragraph.textContent, 'just words');
    });

    test('a table parses without throwing', () {
      expect(
        () => parseMarkdownCached('| a | b |\n|---|---|\n| 1 | 2 |'),
        returnsNormally,
      );
    });
  });

  group('parseMarkdownCached (content-hashed memo)', () {
    test('identical source returns the same cached AST instance', () {
      final first = parseMarkdownCached('# Title\n\nbody');
      final second = parseMarkdownCached('# Title\n\nbody');
      expect(identical(first, second), isTrue);
    });

    test('different source produces a different (non-identical) AST', () {
      final a = parseMarkdownCached('# A');
      final b = parseMarkdownCached('# B');
      expect(identical(a, b), isFalse);
    });

    test('empty source yields an empty node list', () {
      expect(parseMarkdownCached(''), isEmpty);
    });
  });
}
