import 'dart:ui' show Canvas, Offset, Paint, Rect, Size;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/rendering.dart' show CustomPainter;
import 'package:fluvie/src/elements/code/diff/diff_geometry.dart';
import 'package:fluvie/src/elements/code/render/code_layout.dart';
import 'package:fluvie/src/elements/code/theme/code_theme.dart';
import 'package:fluvie/src/elements/runtime/monospace_text.dart';

/// Paints an animated line diff: each [DiffLine] is drawn at
/// its swept [DiffLine.y], faded by its [DiffLine.opacity], with a red / green
/// gutter stripe for removed / inserted lines and no stripe for kept lines.
///
/// Mirrors `CodePainter`: it receives an already-resolved model (the laid-out
/// [lines] from [layoutDiff], their highlighted [tokensPerLine], the [theme],
/// and the reveal [progress]) and draws only that. Capture-safe: opacity rides
/// each glyph's color alpha and the gutter alpha — no `saveLayer`, no
/// `BackdropFilter`. [shouldRepaint] is true exactly when the model differs, so
/// identical frames never repaint.
final class DiffPainter extends CustomPainter {
  /// Creates a painter over the resolved diff [lines] and their tokens.
  DiffPainter({
    required this.lines,
    required this.tokensPerLine,
    required this.theme,
    required this.progress,
    required this.fontFamily,
    required this.fontSize,
  });

  /// The laid-out diff lines, in document order.
  final List<DiffLine> lines;

  /// The highlighted tokens for each line in [lines] (same length, same order).
  final List<List<CodeToken>> tokensPerLine;

  /// The colors this paints with (token colors + chrome + diff gutters).
  final CodeTheme theme;

  /// The reveal progress `0..1` this frame draws at (drives the motion).
  final double progress;

  /// The resolved (package-prefixed) monospace font family.
  final String fontFamily;

  /// The font size lines paint at; the line height is `fontSize * _lineHeight`.
  final double fontSize;

  static const double _lineHeight = 1.4;
  static const double _gutterPad = 8;
  static const double _gutterWidth = 6;

  /// The pixel height of one full line.
  double get lineHeight => fontSize * _lineHeight;

  /// The highlighted tokens for the first line whose text is [text] (test probe
  /// for the both-sides-highlighted assertion).
  List<CodeToken> tokensFor(String text) {
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].text == text) return tokensPerLine[i];
    }
    return const [];
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = theme.background);
    for (var i = 0; i < lines.length; i++) {
      _paintLine(canvas, size, lines[i], tokensPerLine[i]);
    }
  }

  void _paintLine(Canvas canvas, Size size, DiffLine line, List<CodeToken> tokens) {
    final gutter = line.gutter;
    if (gutter != null) {
      canvas.drawRect(
        Rect.fromLTWH(0, line.y, _gutterWidth, lineHeight * line.heightFactor),
        Paint()..color = gutter.withValues(alpha: line.opacity),
      );
    }
    if (line.opacity <= 0) return;
    var x = _gutterWidth + _gutterPad;
    final top = line.y + (lineHeight - fontSize) / 2;
    for (final token in tokens) {
      final painter = layoutMonospaceLine(
        token.text,
        theme.colorFor(token.style),
        fontFamily: fontFamily,
        fontSize: fontSize,
        opacity: line.opacity,
      )..paint(canvas, Offset(x, top));
      x += painter.width;
      painter.dispose();
    }
  }

  @override
  bool shouldRepaint(covariant DiffPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.theme != theme ||
      oldDelegate.fontSize != fontSize ||
      oldDelegate.fontFamily != fontFamily ||
      !listEquals(oldDelegate.lines, lines) ||
      !_tokensEqual(oldDelegate.tokensPerLine, tokensPerLine);

  /// Deep value-equality over the per-line highlight tokens: `paint` reads
  /// [tokensPerLine], so re-highlighting the same text (a language change) must
  /// repaint even when [lines] and [progress] are unchanged. A flat `listEquals`
  /// would compare the inner lists by identity and miss it.
  static bool _tokensEqual(List<List<CodeToken>> a, List<List<CodeToken>> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!listEquals(a[i], b[i])) return false;
    }
    return true;
  }
}
