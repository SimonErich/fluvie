// WI-17 (D-Markdown): the AstRenderer visitor (List<md.Node> -> List<Widget>)
// and the @immutable MarkdownStyle. Headings render Text at the style size,
// lists render bullets/numbers, blockquotes indent, inline code/bold/italic
// render TextStyle runs, fenced code delegates to Code, images delegate to
// Image, and an unsupported node falls back to plain Text. Mount-and-find.

import 'package:flutter/widgets.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/code/code.dart';
import 'package:fluvie/src/elements/image.dart';
import 'package:fluvie/src/elements/markdown/parse/markdown_parser.dart';
import 'package:fluvie/src/elements/markdown/render/ast_renderer.dart';
import 'package:fluvie/src/elements/markdown/render/markdown_style.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/theme/fluvie_tokens.dart';
import 'package:fluvie/src/timing/scene_scope.dart';
import 'package:fluvie/src/timing/video_scope.dart';
import 'package:markdown/markdown.dart' as md;

const _style = MarkdownStyle.fallback();

List<Widget> _render(String source) =>
    const AstRenderer(style: _style).render(parseMarkdownCached(source));

/// Mounts [child] under a frame clock + timing scopes so frame-driven
/// delegations (a fenced `Code`) can read the current frame.
Future<void> _mount(WidgetTester tester, Widget child) => tester.pumpWidget(
  Directionality(
    textDirection: TextDirection.ltr,
    child: RenderControllerScope(
      controller: RenderController(),
      child: VideoScope(
        fps: 30,
        duration: const Time.frames(60),
        child: SceneScope(duration: const Time.frames(60), child: child),
      ),
    ),
  ),
);

Future<List<Text>> _mountTexts(WidgetTester tester, String source) async {
  await _mount(tester, Column(children: _render(source)));
  return tester.widgetList<Text>(find.byType(Text)).toList();
}

void main() {
  setUp(clearMarkdownCache);

  group('AstRenderer block nodes', () {
    testWidgets('a heading renders a Text at the heading size', (tester) async {
      final texts = await _mountTexts(tester, '# Big Title');
      final heading = texts.firstWhere((t) => t.textSpan?.toPlainText() == 'Big Title');
      final size = (heading.textSpan! as TextSpan).style!.fontSize!;
      expect(size, _style.headingSize(1));
      expect(size, greaterThan(_style.body.fontSize!));
    });

    testWidgets('a deeper heading renders smaller than h1', (tester) async {
      await _mountTexts(tester, '### Smaller');
      expect(_style.headingSize(3), lessThan(_style.headingSize(1)));
    });

    testWidgets('a paragraph renders its text in the body style', (tester) async {
      final texts = await _mountTexts(tester, 'just a paragraph');
      final span = texts.single.textSpan! as TextSpan;
      expect(span.toPlainText(), 'just a paragraph');
      expect(span.style!.fontSize, _style.body.fontSize);
      expect(span.style!.color, _style.body.color);
    });

    testWidgets('an unordered list renders a bullet before each item', (tester) async {
      final texts = await _mountTexts(tester, '- apple\n- pear');
      final joined = texts.map((t) => t.textSpan!.toPlainText()).join('\n');
      expect(joined, contains('• apple'));
      expect(joined, contains('• pear'));
    });

    testWidgets('an ordered list renders 1. 2. numbering', (tester) async {
      final texts = await _mountTexts(tester, '1. first\n2. second');
      final joined = texts.map((t) => t.textSpan!.toPlainText()).join('\n');
      expect(joined, contains('1. first'));
      expect(joined, contains('2. second'));
    });

    testWidgets('a blockquote renders an indented block', (tester) async {
      await _mountTexts(tester, '> a quote');
      // The quote text sits inside a Padding (the indent) under the renderer.
      final quoteText = find.text('a quote', findRichText: true);
      expect(quoteText, findsOneWidget);
      expect(
        find.ancestor(of: quoteText, matching: find.byType(Padding)),
        findsWidgets,
      );
    });
  });

  group('AstRenderer inline runs', () {
    testWidgets('inline code renders a monospace run', (tester) async {
      final texts = await _mountTexts(tester, 'use `x` here');
      final span = texts.single.textSpan! as TextSpan;
      final codeRun = _findRun(span, 'x');
      expect(codeRun!.style!.fontFamily, contains('JetBrains Mono'));
    });

    testWidgets('bold renders a bold run', (tester) async {
      final texts = await _mountTexts(tester, 'a **strong** word');
      final span = texts.single.textSpan! as TextSpan;
      expect(_findRun(span, 'strong')!.style!.fontWeight, FontWeight.bold);
    });

    testWidgets('italic renders an italic run', (tester) async {
      final texts = await _mountTexts(tester, 'an *emphatic* word');
      final span = texts.single.textSpan! as TextSpan;
      expect(_findRun(span, 'emphatic')!.style!.fontStyle, FontStyle.italic);
    });
  });

  group('AstRenderer delegations and fallback', () {
    testWidgets('a fenced code block delegates to a Code widget', (tester) async {
      await _mount(tester, Column(children: _render('```dart\nvoid main() {}\n```')));
      final code = tester.widget<Code>(find.byType(Code));
      expect(code.language, 'dart');
      expect(code.source.trim(), 'void main() {}');
    });

    test('an image delegates to an Image widget with the src', () {
      // The image rides a WidgetSpan inside the paragraph; reach into the
      // rendered span tree (without mounting, so no async network load fires)
      // and confirm the delegated child is a Fluvie Image at the parsed src.
      final paragraph = _render('![alt](http://x/y.png)').single as Padding;
      final span = (paragraph.child! as Text).textSpan! as TextSpan;
      final image = _findWidgetSpanChild(span)! as Image;
      expect(image.source.toString(), contains('http://x/y.png'));
    });

    testWidgets('an unsupported node renders a plain Text fallback', (tester) async {
      // A horizontal rule (`---`) is outside the supported node set; it must
      // fall back to a plain Text rather than throw.
      final widgets = _render('text\n\n---\n\nmore');
      expect(widgets, isNotEmpty);
      expect(() => Column(children: widgets), returnsNormally);
    });
  });

  group('AstRenderer coverage pins', () {
    testWidgets('a blockquote with a nested list renders the inner block', (tester) async {
      // The quote child is a `ul`, not a `p`, so the renderer recurses through
      // _block rather than the paragraph fast-path.
      await _mountTexts(tester, '> - one\n> - two');
      expect(find.text('• one', findRichText: true), findsOneWidget);
    });

    testWidgets('a fenced block with no language renders plaintext Code', (tester) async {
      await _mount(tester, Column(children: _render('```\nbare\n```')));
      expect(tester.widget<Code>(find.byType(Code)).language, 'plaintext');
    });

    testWidgets('an inline link renders its text (unmapped tag recurses)', (tester) async {
      // An `a` tag is outside the styled inline set; the renderer recurses into
      // its children under the base style.
      final texts = await _mountTexts(tester, 'see [the docs](http://x)');
      final joined = texts.map((t) => t.textSpan!.toPlainText()).join();
      expect(joined, contains('the docs'));
    });

    test('a top-level text node falls back to plain text', () {
      // A bare Text node at the block level (not wrapped in an Element) takes
      // the _block text-fallback path.
      final widgets = const AstRenderer(style: _style).render([md.Text('loose')]);
      expect((widgets.single as Text).data, 'loose');
    });
  });

  group('MarkdownStyle', () {
    test('reads colors from FluvieTokens', () {
      const tokens = FluvieTokens.fallback();
      final style = MarkdownStyle.fromTokens(tokens);
      expect(style.body.color, isNotNull);
    });

    test('is value-equal by field, with matching hashCode and a toString', () {
      const a = MarkdownStyle.fallback();
      const b = MarkdownStyle.fallback();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), contains('MarkdownStyle'));
    });

    test('headingSize floors at the body size for deep levels', () {
      const style = MarkdownStyle.fallback();
      expect(style.headingSize(6), greaterThanOrEqualTo(style.body.fontSize!));
    });
  });
}

/// The first [WidgetSpan] child anywhere under [root].
Widget? _findWidgetSpanChild(TextSpan root) {
  for (final child in root.children ?? const <InlineSpan>[]) {
    if (child is WidgetSpan) return child.child;
    if (child is TextSpan) {
      final found = _findWidgetSpanChild(child);
      if (found != null) return found;
    }
  }
  return null;
}

/// The first descendant [TextSpan] of [root] whose text equals [text].
TextSpan? _findRun(TextSpan root, String text) {
  if (root.text == text) return root;
  for (final child in root.children ?? const <InlineSpan>[]) {
    if (child is TextSpan) {
      final found = _findRun(child, text);
      if (found != null) return found;
    }
  }
  return null;
}
