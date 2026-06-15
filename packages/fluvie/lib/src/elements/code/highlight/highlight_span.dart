import 'package:fluvie/src/elements/code/highlight/token_style.dart';
import 'package:meta/meta.dart' show immutable;

/// One run of source text classified by its [style].
///
/// A `SyntaxHighlighter` returns a flat list of these whose concatenated [text]
/// equals the original source (lossless), so the reveal arithmetic indexes into
/// one joined string while the painter still colors each run by its kind.
///
/// Value-equal by field, so two highlights of the same source produce identical
/// span lists — the frame-caching contract.
@immutable
final class HighlightSpan {
  /// Creates a span over [text] classified as [style].
  const HighlightSpan(this.text, this.style);

  /// The literal source run this span covers.
  final String text;

  /// The token kind that colors this run.
  final TokenStyle style;

  @override
  bool operator ==(Object other) =>
      other is HighlightSpan && other.text == text && other.style == style;

  @override
  int get hashCode => Object.hash(HighlightSpan, text, style);

  @override
  String toString() => 'HighlightSpan(${text.length} chars, $style)';
}
