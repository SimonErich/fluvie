import 'package:flutter/widgets.dart'
    show
        Column,
        CrossAxisAlignment,
        EdgeInsets,
        InlineSpan,
        Padding,
        Text,
        TextSpan,
        TextStyle,
        Widget,
        WidgetSpan;
import 'package:fluvie/src/elements/code/code.dart';
import 'package:fluvie/src/elements/image.dart';
import 'package:fluvie/src/elements/markdown/render/markdown_style.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:meta/meta.dart' show immutable;

/// The bundled monospace family inline code renders in.
const String _monoFamily = 'packages/fluvie/JetBrains Mono';

/// Renders a `markdown` package AST to Fluvie / Flutter widgets.
///
/// A visitor over a `List<md.Node>`: every top-level block becomes one [Widget]
/// via [render], and the inline runs inside a block become [InlineSpan]s colored
/// and weighted by the [style]. The renderer handles the supported node kinds
/// (headings, paragraphs, lists, blockquotes, inline code / bold / italic,
/// fenced code, images); a fenced block delegates to a [Code] widget and an
/// image to an [Image] widget. Any other node falls back to a plain [Text] of
/// its text content, so an unknown construct never throws.
///
/// Pure: the same AST and [style] always produce the same widget list, so
/// `Markdown` stays a deterministic function of its content.
@immutable
final class AstRenderer {
  /// Creates a renderer styling its output with [style].
  const AstRenderer({required this.style});

  /// The text styles every rendered run reads.
  final MarkdownStyle style;

  /// Renders [nodes] (one document's top-level blocks) to a widget list.
  List<Widget> render(List<md.Node> nodes) => [
    for (final node in nodes) _block(node),
  ];

  /// Renders one top-level block [node] to a widget.
  Widget _block(md.Node node) {
    if (node is md.Element) {
      return switch (node.tag) {
        'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6' => _heading(node),
        'p' => _paragraph(node),
        'ul' => _list(node, ordered: false),
        'ol' => _list(node, ordered: true),
        'blockquote' => _blockquote(node),
        'pre' => _fencedCode(node),
        _ => _fallback(node),
      };
    }
    return _fallback(node);
  }

  /// A heading: its inline runs at the level's size, weighted bold. The root
  /// span carries the heading style so a plain `# Title` reads its size off the
  /// top-level span (no nested run required).
  Widget _heading(md.Element node) {
    final level = int.parse(node.tag.substring(1));
    final headingStyle = style.bold.copyWith(fontSize: style.headingSize(level));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text.rich(
        TextSpan(style: headingStyle, children: _inline(node.children, headingStyle)),
      ),
    );
  }

  /// A paragraph: its inline runs in the body style. The root span carries the
  /// body style so a plain paragraph reads its size off the top-level span.
  Widget _paragraph(md.Element node) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text.rich(TextSpan(style: style.body, children: _inline(node.children, style.body))),
  );

  /// A list: one bullet or numbered row per item.
  Widget _list(md.Element node, {required bool ordered}) {
    final items = (node.children ?? const <md.Node>[]).whereType<md.Element>().toList();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i++)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: ordered ? '${i + 1}. ' : '• ', style: style.body),
                  ..._inline(items[i].children, style.body),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// A blockquote: its child blocks indented behind a left margin.
  Widget _blockquote(md.Element node) => Padding(
    padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final child in node.children ?? const <md.Node>[])
          if (child is md.Element && child.tag == 'p')
            Text.rich(TextSpan(children: _inline(child.children, style.quote)))
          else
            _block(child),
      ],
    ),
  );

  /// A fenced code block: delegate to a [Code] widget at its declared language.
  Widget _fencedCode(md.Element node) {
    final code = (node.children ?? const <md.Node>[]).whereType<md.Element>().firstWhere(
      (e) => e.tag == 'code',
      // coverage:ignore-line the parser always nests pre code defensive
      orElse: () => md.Element.text('code', node.textContent),
    );
    final language = _languageOf(code.attributes['class']);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Code(_stripTrailingNewline(code.textContent), language: language),
    );
  }

  /// A fallback for an unsupported node: its plain text in the body style.
  Widget _fallback(md.Node node) {
    final text = node.textContent.trim();
    return Text(text, style: style.body);
  }

  /// The inline runs of [children] under [base], descending into emphasis,
  /// inline code, and images (which become [WidgetSpan]s).
  List<InlineSpan> _inline(List<md.Node>? children, TextStyle base) => [
    for (final node in children ?? const <md.Node>[]) _span(node, base),
  ];

  /// One inline [node] as a span under [base].
  InlineSpan _span(md.Node node, TextStyle base) {
    if (node is md.Text) return TextSpan(text: node.text, style: base);
    if (node is md.Element) {
      return switch (node.tag) {
        'code' => TextSpan(text: node.textContent, style: _codeRun(base)),
        'strong' => TextSpan(children: _inline(node.children, _boldOf(base))),
        'em' => TextSpan(children: _inline(node.children, _italicOf(base))),
        'img' => _imageSpan(node),
        _ => TextSpan(children: _inline(node.children, base)),
      };
    }
    // coverage:ignore-line inline nodes are always Text or Element post parse
    return TextSpan(text: node.textContent, style: base);
  }

  /// An image delegated to an [Image] widget, sized into the run as a span.
  InlineSpan _imageSpan(md.Element node) {
    final src = node.attributes['src'] ?? '';
    return WidgetSpan(child: Image.network(src));
  }

  /// The inline-code run style: monospace, in the theme's code color.
  TextStyle _codeRun(TextStyle base) =>
      base.copyWith(fontFamily: _monoFamily, color: style.code.color);

  /// [base] made bold, preserving its size and color.
  TextStyle _boldOf(TextStyle base) => base.copyWith(fontWeight: style.bold.fontWeight);

  /// [base] made italic, preserving its size and color.
  TextStyle _italicOf(TextStyle base) => base.copyWith(fontStyle: style.italic.fontStyle);

  /// The highlight language from a `language-xxx` CSS class, or `plaintext`.
  String _languageOf(String? cssClass) {
    if (cssClass == null) return 'plaintext';
    const prefix = 'language-';
    return cssClass.startsWith(prefix) ? cssClass.substring(prefix.length) : cssClass;
  }

  /// Drops the single trailing newline `markdown` keeps on a fenced block.
  String _stripTrailingNewline(String text) =>
      text.endsWith('\n') ? text.substring(0, text.length - 1) : text;
}
