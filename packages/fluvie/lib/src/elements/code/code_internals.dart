part of 'code.dart';

/// Whether a [Code] renders a plain highlight or an animated line diff — the
/// discriminator the part's painter dispatch switches on.
enum _CodeKind {
  /// A plain syntax-highlighted source view (the default `Code(...)`).
  highlight,

  /// An animated `before -> after` line diff ([Code.diff]).
  diff,
}

/// The default font size `Code` paints at when [Code.style] gives none.
const double _defaultFontSize = 14;

/// The line-height multiple shared between the painter and the diff geometry, so
/// the laid-out y positions match the painter's line stride.
const double _diffLineHeight = 1.4;

/// Builds the resolved [CodePainter] for a `Code` element.
///
/// Pure given its inputs: it highlights [source] once (cached by content hash),
/// lays the spans out into lines, resolves [reveal] to a visible-glyph cutoff
/// over the joined source, and hands the painter the laid-out lines plus the
/// focus / highlight sets and the resolved [theme]. The `build` keeps only the
/// frame / scope read; all the model work lives here, off the widget.
CodePainter _buildCodePainter({
  required String source,
  required String language,
  required CodeReveal reveal,
  required Set<int>? focusLines,
  required Set<int>? highlightLines,
  required CodeTheme theme,
  required TextStyle? style,
  required int elapsed,
  required TimeScopeData scope,
}) {
  final spans = highlightCached(source, language, Code.highlighter);
  final lines = layoutCodeLines(spans);
  final lineLengths = [for (final line in lines) line.length];
  final state = resolveCodeReveal(
    reveal: reveal,
    elapsed: elapsed,
    totalGlyphs: source.length,
    lineLengths: lineLengths,
    scope: scope,
  );
  return CodePainter(
    lines: lines,
    visibleGlyphs: state.visibleGlyphs,
    caretOn: state.caretOn,
    focusLines: focusLines,
    highlightLines: highlightLines,
    theme: theme,
    fontFamily: style?.fontFamily ?? Code.defaultFontFamily,
    fontSize: style?.fontSize ?? _defaultFontSize,
  );
}

/// Builds the resolved [DiffPainter] for a [Code.diff] element.
///
/// Pure given its inputs: it highlights both [before] and [after] once (cached
/// by content hash), diffs them line by line ([lineDiff]), resolves [reveal] to
/// a `0..1` motion progress over the element window, lays the ops out into
/// stacked diff lines ([layoutDiff]), and matches each op to its highlighted
/// tokens (removed / kept lines from the `before` layout, inserted lines from
/// the `after` layout). The painter then draws that model with no per-frame
/// parsing.
DiffPainter _buildDiffPainter({
  required String before,
  required String after,
  required String language,
  required CodeReveal reveal,
  required CodeTheme theme,
  required TextStyle? style,
  required int frame,
  required TimeScopeData scope,
}) {
  final beforeLines = layoutCodeLines(highlightCached(before, language, Code.highlighter));
  final afterLines = layoutCodeLines(highlightCached(after, language, Code.highlighter));
  final ops = lineDiff(_textLines(before), _textLines(after));
  final progress = _diffProgress(reveal, frame, scope);
  final fontSize = style?.fontSize ?? _defaultFontSize;
  final lines = layoutDiff(
    ops: ops,
    progress: progress,
    theme: theme,
    lineHeight: fontSize * _diffLineHeight,
  );
  return DiffPainter(
    lines: lines,
    tokensPerLine: _tokensForOps(ops, beforeLines, afterLines),
    theme: theme,
    progress: progress,
    fontFamily: style?.fontFamily ?? Code.defaultFontFamily,
    fontSize: fontSize,
  );
}

/// The lines of [source], split on `\n` with no trailing empty line so a final
/// newline does not add a phantom blank line to the diff.
List<String> _textLines(String source) {
  if (source.isEmpty) return const [];
  final lines = source.split('\n');
  if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
  return lines;
}

/// The `0..1` motion progress for [reveal] at [frame].
///
/// `instant` finishes immediately (progress `1`); a timed reveal animates over
/// its single `Time` resolved against [scope], so `lineByLine(12.frames)` runs
/// the whole diff across twelve frames. Reuses [revealProgress] so the diff
/// shares the one reveal-math home.
double _diffProgress(CodeReveal reveal, int frame, TimeScopeData scope) => switch (reveal) {
  InstantReveal() => 1,
  TypingReveal(:final speed) => revealProgress(frame, scope, speed),
  LineByLineReveal(:final perLine) => revealProgress(frame, scope, perLine),
};

/// One token run list per op, sourced from the matching highlighted side: a
/// [Keep] or [Remove] from the `before` layout, an [Insert] from the `after`
/// layout, each consuming the next line on its side so duplicate lines map in
/// order.
List<List<CodeToken>> _tokensForOps(
  List<DiffOp> ops,
  List<CodeLine> beforeLines,
  List<CodeLine> afterLines,
) {
  final result = <List<CodeToken>>[];
  var beforeCursor = 0;
  var afterCursor = 0;
  for (final op in ops) {
    switch (op) {
      case Keep():
        result.add(beforeLines[beforeCursor].tokens);
        beforeCursor++;
        afterCursor++;
      case Remove():
        result.add(beforeLines[beforeCursor].tokens);
        beforeCursor++;
      case Insert():
        result.add(afterLines[afterCursor].tokens);
        afterCursor++;
    }
  }
  return result;
}
