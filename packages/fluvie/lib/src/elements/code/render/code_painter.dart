import 'dart:ui' show Canvas, Offset, Paint, Rect, Size;

import 'package:flutter/rendering.dart' show CustomPainter;
import 'package:fluvie/src/elements/code/render/code_layout.dart';
import 'package:fluvie/src/elements/code/theme/code_theme.dart';
import 'package:fluvie/src/elements/runtime/monospace_text.dart';

/// Paints highlighted [lines] with a line-number gutter, per-line focus dimming,
/// per-line highlight tint, the typed-reveal cutoff, and a blinking caret.
///
/// Mirrors `ChartPainter`: it receives an already-resolved model (the laid-out
/// [lines], the [visibleGlyphs] cutoff, the focus / highlight line sets, and the
/// [theme]) and draws only that. [shouldRepaint] is true exactly when those
/// differ (frame-correct, never time-based), so identical frames never repaint.
/// Capture-safe: opacity rides each glyph's color alpha — no `saveLayer`, no
/// `BackdropFilter`.
final class CodePainter extends CustomPainter {
  /// Creates a painter over the resolved [lines] and reveal / focus / theme.
  CodePainter({
    required this.lines,
    required this.visibleGlyphs,
    required this.caretOn,
    required this.focusLines,
    required this.highlightLines,
    required this.theme,
    required this.fontFamily,
    required this.fontSize,
  });

  /// The laid-out code lines, in order.
  final List<CodeLine> lines;

  /// The number of leading joined-source glyphs that are visible (the reveal
  /// cutoff); a token starting at or after this is not drawn.
  final int visibleGlyphs;

  /// Whether to draw a caret after the last visible glyph.
  final bool caretOn;

  /// The 1-based line numbers to keep at full opacity; when non-null every other
  /// line dims to [CodeTheme.dimOpacity]. `null` keeps all lines lit.
  final Set<int>? focusLines;

  /// The 1-based line numbers whose background is tinted with
  /// [CodeTheme.highlightColor]. `null` tints nothing.
  final Set<int>? highlightLines;

  /// The colors this paints with (token colors + chrome).
  final CodeTheme theme;

  /// The resolved (package-prefixed) monospace font family.
  final String fontFamily;

  /// The font size lines paint at; the line height is `fontSize * _lineHeight`.
  final double fontSize;

  static const double _lineHeight = 1.4;
  static const double _gutterPad = 8;
  static const double _digitWidth = 0.62;

  /// The pixel height of one line.
  double get lineHeight => fontSize * _lineHeight;

  /// The pixel width of the line-number gutter.
  double get gutterWidth => _gutterPad * 2 + fontSize * _digitWidth * '${lines.length}'.length;

  /// The opacity line [number] (1-based) paints at: `1.0` when focused or when
  /// no focus is set, else [CodeTheme.dimOpacity].
  double lineOpacity(int number) {
    final focus = focusLines;
    if (focus == null || focus.contains(number)) return 1;
    return theme.dimOpacity;
  }

  /// Whether line [number] (1-based) is highlighted (its background tinted).
  bool isHighlighted(int number) => highlightLines?.contains(number) ?? false;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..drawRect(Offset.zero & size, Paint()..color = theme.background)
      ..drawRect(
        Rect.fromLTWH(0, 0, gutterWidth, size.height),
        Paint()..color = theme.gutterColor,
      );
    final highlight = Paint()..color = theme.highlightColor;
    for (final line in lines) {
      final y = (line.number - 1) * lineHeight;
      if (isHighlighted(line.number)) {
        canvas.drawRect(
          Rect.fromLTWH(gutterWidth, y, size.width - gutterWidth, lineHeight),
          highlight,
        );
      }
      _paintLineNumber(canvas, line, y);
      _paintTokens(canvas, line, y);
    }
    if (caretOn) _paintCaret(canvas);
  }

  void _paintLineNumber(Canvas canvas, CodeLine line, double y) {
    layoutMonospaceLine(
        '${line.number}',
        theme.lineNumberColor,
        fontFamily: fontFamily,
        fontSize: fontSize,
        opacity: lineOpacity(line.number),
      )
      ..paint(canvas, Offset(_gutterPad, y + (lineHeight - fontSize) / 2))
      ..dispose();
  }

  void _paintTokens(Canvas canvas, CodeLine line, double y) {
    final opacity = lineOpacity(line.number);
    var x = gutterWidth + _gutterPad;
    final top = y + (lineHeight - fontSize) / 2;
    for (final token in line.tokens) {
      if (token.start >= visibleGlyphs) break;
      final shown = token.start + token.text.length <= visibleGlyphs
          ? token.text
          : token.text.substring(0, visibleGlyphs - token.start);
      final painter = layoutMonospaceLine(
        shown,
        theme.colorFor(token.style),
        fontFamily: fontFamily,
        fontSize: fontSize,
        opacity: opacity,
      )..paint(canvas, Offset(x, top));
      x += painter.width;
      painter.dispose();
    }
  }

  void _paintCaret(Canvas canvas) {
    var glyphsBefore = 0;
    var caretLine = lines.isEmpty ? 1 : lines.first.number;
    var column = 0;
    for (final line in lines) {
      if (glyphsBefore + line.length > visibleGlyphs) {
        caretLine = line.number;
        column = visibleGlyphs - glyphsBefore;
        break;
      }
      glyphsBefore += line.length;
      caretLine = line.number;
      column = line.length;
    }
    final x = gutterWidth + _gutterPad + fontSize * _digitWidth * column;
    final top = (caretLine - 1) * lineHeight + (lineHeight - fontSize) / 2;
    canvas.drawRect(Rect.fromLTWH(x, top, fontSize * 0.1, fontSize), Paint()..color = theme.plain);
  }

  @override
  bool shouldRepaint(covariant CodePainter oldDelegate) =>
      oldDelegate.visibleGlyphs != visibleGlyphs ||
      oldDelegate.caretOn != caretOn ||
      oldDelegate.focusLines != focusLines ||
      oldDelegate.highlightLines != highlightLines ||
      oldDelegate.theme != theme ||
      oldDelegate.fontSize != fontSize ||
      !identical(oldDelegate.lines, lines);
}
