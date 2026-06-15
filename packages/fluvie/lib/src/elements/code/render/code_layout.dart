import 'package:fluvie/src/elements/code/highlight/highlight_span.dart';
import 'package:fluvie/src/elements/code/highlight/token_style.dart';
import 'package:meta/meta.dart' show immutable;

/// One painted token within a code line: its [text], its [style], and the
/// [start] glyph offset of its first character within the joined source.
///
/// The painter compares [start] (and the run length) against the reveal cutoff
/// so a run that straddles the typed boundary draws only its revealed prefix.
@immutable
final class CodeToken {
  /// Creates a token over [text] of [style] beginning at joined offset [start].
  const CodeToken({required this.text, required this.style, required this.start});

  /// The literal text of this run (newlines already stripped by the splitter).
  final String text;

  /// The token kind, coloring this run via the theme.
  final TokenStyle style;

  /// The glyph offset of this run's first character within the joined source.
  final int start;

  @override
  bool operator ==(Object other) =>
      other is CodeToken && other.text == text && other.style == style && other.start == start;

  @override
  int get hashCode => Object.hash(CodeToken, text, style, start);
}

/// One laid-out code line: its 1-based [number], its [tokens] (newline removed),
/// and the joined-source [length] of the original line including its newline.
@immutable
final class CodeLine {
  /// Creates a line numbered [number] over [tokens], spanning [length] glyphs of
  /// the joined source (including the trailing newline, if any).
  const CodeLine({required this.number, required this.tokens, required this.length});

  /// The 1-based line number painted in the gutter.
  final int number;

  /// The colored runs on this line, in order, with their joined offsets.
  final List<CodeToken> tokens;

  /// The number of joined-source glyphs this line occupies (text + newline).
  final int length;
}

/// The per-spans layout memo, keyed by the (identity-stable, cache-shared)
/// highlighted spans list — so two `Code` builds of the same content share one
/// laid-out line list and the painter's `shouldRepaint` stays frame-stable.
final Expando<List<CodeLine>> _layoutCache = Expando<List<CodeLine>>();

/// Splits the highlighted [spans] into per-line [CodeLine]s.
///
/// Pure layout: the spans are walked once, broken at `\n`, and each run records
/// its joined-source [CodeToken.start] so the painter can clip to the reveal
/// cutoff. The newline glyph is counted in [CodeLine.length] (so the line counts
/// sum to the joined length) but is not part of any token's drawn text. An empty
/// source yields a single empty line so the gutter always shows line 1. The
/// result is memoized against the [spans] identity so the same cached highlight
/// lays out only once.
List<CodeLine> layoutCodeLines(List<HighlightSpan> spans) {
  final cached = _layoutCache[spans];
  if (cached != null) return cached;
  final result = List<CodeLine>.unmodifiable(_layoutLines(spans));
  _layoutCache[spans] = result;
  return result;
}

List<CodeLine> _layoutLines(List<HighlightSpan> spans) {
  final lines = <CodeLine>[];
  var lineTokens = <CodeToken>[];
  var lineLength = 0;
  var offset = 0;
  var lineNumber = 1;

  void endLine({required bool hadNewline}) {
    lines.add(
      CodeLine(number: lineNumber, tokens: lineTokens, length: lineLength + (hadNewline ? 1 : 0)),
    );
    lineNumber++;
    lineTokens = <CodeToken>[];
    lineLength = 0;
  }

  for (final span in spans) {
    final parts = span.text.split('\n');
    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (part.isNotEmpty) {
        lineTokens.add(CodeToken(text: part, style: span.style, start: offset));
        lineLength += part.length;
        offset += part.length;
      }
      if (i < parts.length - 1) {
        endLine(hadNewline: true);
        offset += 1; // the consumed newline.
      }
    }
  }
  endLine(hadNewline: false);
  return lines;
}
