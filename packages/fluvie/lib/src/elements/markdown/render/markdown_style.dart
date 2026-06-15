import 'package:flutter/painting.dart' show Color, FontStyle, FontWeight, TextStyle;
import 'package:fluvie/src/theme/fluvie_tokens.dart';
import 'package:meta/meta.dart' show immutable;

/// The bundled monospace family inline `code` and fenced blocks render in,
/// addressed through the `fluvie` package.
const String _monoFamily = 'packages/fluvie/JetBrains Mono';

/// The text styles a `Markdown` element renders its AST with.
///
/// A `MarkdownStyle` carries the [body] paragraph style, the [code] inline-code
/// style, the [quote] blockquote style, and the [headingScale] that sizes a
/// heading by its level via [headingSize]. It is `@immutable` and value-equal by
/// field, so two builds of the same document render identically and the
/// repaint / parse caches stay frame-stable.
///
/// Build one from `context.fluvie` with [MarkdownStyle.fromTokens] so the text
/// color follows the theme, or take the neutral [MarkdownStyle.fallback].
@immutable
final class MarkdownStyle {
  /// Creates a style from an explicit [body], [code], [quote], [headingScale],
  /// and [headingBase] size.
  const MarkdownStyle({
    required this.body,
    required this.code,
    required this.quote,
    this.headingScale = 1.5,
    this.headingBase = 32,
  });

  /// The neutral default: light body text, a muted blockquote, monospace inline
  /// code, on a dark background (matching [CodeTheme.dark]).
  const MarkdownStyle.fallback()
    : body = const TextStyle(color: Color(0xFFE0E0E0), fontSize: 18),
      code = const TextStyle(
        color: Color(0xFFCE9178),
        fontSize: 16,
        fontFamily: _monoFamily,
      ),
      quote = const TextStyle(color: Color(0xFF9E9E9E), fontSize: 18, fontStyle: FontStyle.italic),
      headingScale = 1.5,
      headingBase = 32;

  /// Builds a style whose colors follow [tokens]: the body reads `labelColor`,
  /// the inline code reads the code theme's string color, and the quote reads a
  /// muted `axisColor`.
  factory MarkdownStyle.fromTokens(FluvieTokens tokens) => MarkdownStyle(
    body: TextStyle(color: tokens.labelColor, fontSize: 18),
    code: TextStyle(color: tokens.code.string, fontSize: 16, fontFamily: _monoFamily),
    quote: TextStyle(color: tokens.axisColor, fontSize: 18, fontStyle: FontStyle.italic),
  );

  /// The paragraph and list-item text style.
  final TextStyle body;

  /// The inline-code run style (monospace).
  final TextStyle code;

  /// The blockquote text style.
  final TextStyle quote;

  /// The geometric factor each heading level shrinks by: level `n` is
  /// `headingBase * headingScale^(1 - n)`.
  final double headingScale;

  /// The font size of a level-1 heading; deeper levels shrink by [headingScale].
  final double headingBase;

  /// The font size of a heading at [level] (1 = `h1`): [headingBase] for level
  /// 1, divided by [headingScale] for each level deeper, floored at the [body]
  /// size so an `h6` never reads smaller than a paragraph.
  double headingSize(int level) {
    var size = headingBase;
    for (var i = 1; i < level; i++) {
      size /= headingScale;
    }
    final floor = body.fontSize ?? 16;
    return size < floor ? floor : size;
  }

  /// The [body] style made bold for a `**strong**` run.
  TextStyle get bold => body.copyWith(fontWeight: FontWeight.bold);

  /// The [body] style made italic for an `*emphasis*` run.
  TextStyle get italic => body.copyWith(fontStyle: FontStyle.italic);

  @override
  bool operator ==(Object other) =>
      other is MarkdownStyle &&
      other.body == body &&
      other.code == code &&
      other.quote == quote &&
      other.headingScale == headingScale &&
      other.headingBase == headingBase;

  @override
  int get hashCode => Object.hash(MarkdownStyle, body, code, quote, headingScale, headingBase);

  @override
  String toString() => 'MarkdownStyle(body: $body)';
}
