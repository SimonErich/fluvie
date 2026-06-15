import 'package:fluvie/src/elements/code/highlight/highlight_span.dart';
import 'package:fluvie/src/elements/code/highlight/syntax_highlighter.dart';
import 'package:fluvie/src/elements/code/highlight/token_style.dart';
import 'package:highlight/highlight.dart' as hljs;
import 'package:highlight/highlight_core.dart' show Node;

/// The default [SyntaxHighlighter], backed by the highlight.js Dart port.
///
/// It calls `highlight.parse(source, language:)` once and flattens the returned
/// node tree to a lossless [HighlightSpan] list, mapping highlight.js class names
/// (`keyword`, `string`, `comment`, `number`, `built_in`, `class`, `title`, …)
/// to Fluvie [TokenStyle] kinds — the class-name-to-kind map is ours, so the
/// theme (not the package) dictates colors. The tokenizer is pure (no IO, clock,
/// or randomness), so given the pinned dep the spans are byte-identical across
/// machines and re-renders.
final class HighlightJsHighlighter implements SyntaxHighlighter {
  /// Creates the default highlight.js-backed highlighter.
  const HighlightJsHighlighter();

  @override
  List<HighlightSpan> highlight(String source, String language) {
    if (source.isEmpty) return const [];
    final nodes = hljs.highlight.parse(source, language: language).nodes ?? const [];
    final spans = <HighlightSpan>[];
    for (final node in nodes) {
      _flatten(node, TokenStyle.plain, spans);
    }
    return _coalesce(spans);
  }

  /// Appends leaf-text spans for [node] under the effective [inherited] style.
  void _flatten(Node node, TokenStyle inherited, List<HighlightSpan> out) {
    final style = _styleFor(node.className, inherited);
    final value = node.value;
    if (value != null) {
      if (value.isNotEmpty) out.add(HighlightSpan(value, style));
      return;
    }
    for (final child in node.children ?? const <Node>[]) {
      _flatten(child, style, out);
    }
  }

  /// The [TokenStyle] for a node's [className], inheriting [parent] when the
  /// class name is null or unmapped.
  TokenStyle _styleFor(String? className, TokenStyle parent) => switch (className) {
    null => parent,
    'keyword' || 'literal' => TokenStyle.keyword,
    'string' || 'regexp' || 'meta-string' => TokenStyle.string,
    'comment' || 'quote' => TokenStyle.comment,
    'number' => TokenStyle.number,
    'type' || 'class' || 'built_in' => TokenStyle.type,
    'function' => TokenStyle.function,
    'title' => parent == TokenStyle.type ? TokenStyle.type : TokenStyle.function,
    'operator' || 'punctuation' => TokenStyle.punctuation,
    _ => parent,
  };

  /// Merges adjacent same-style spans so the painter draws fewer, larger runs
  /// (purely cosmetic; the joined text is unchanged).
  List<HighlightSpan> _coalesce(List<HighlightSpan> spans) {
    final out = <HighlightSpan>[];
    for (final span in spans) {
      if (out.isNotEmpty && out.last.style == span.style) {
        out[out.length - 1] = HighlightSpan(out.last.text + span.text, span.style);
      } else {
        out.add(span);
      }
    }
    return out;
  }
}
