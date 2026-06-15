import 'dart:ui' show Canvas, Color, Offset, Paint, Rect, Size;

import 'package:flutter/rendering.dart' show CustomPainter;
import 'package:fluvie/src/elements/code/theme/code_theme.dart';
import 'package:fluvie/src/elements/runtime/monospace_text.dart';
import 'package:fluvie/src/elements/terminal/render/terminal_layout.dart';
import 'package:fluvie/src/elements/terminal/terminal_chrome.dart';
import 'package:fluvie/src/elements/terminal/terminal_line.dart';

/// Paints a `Terminal`: an optional window chrome bar, then each started line as
/// a typed command (prompt + typed glyphs + blinking caret) or streamed output.
///
/// Mirrors `CodePainter`: it receives an already-resolved model (the [lines], the
/// per-line [states] from `terminalReveal`, the [chrome], the [prompt], and the
/// [theme]) and draws only that. [shouldRepaint] is true exactly when those
/// differ (frame-correct, never time-based). Capture-safe: every color is opaque
/// or carries its own alpha, so there is no `saveLayer` and no `BackdropFilter`.
final class TerminalPainter extends CustomPainter {
  /// Creates a painter over the resolved [lines] and their [states].
  TerminalPainter({
    required this.lines,
    required this.states,
    required this.prompt,
    required this.chrome,
    required this.theme,
    required this.fontFamily,
    required this.fontSize,
  });

  /// The terminal lines, in order.
  final List<TerminalLine> lines;

  /// The per-line reveal state at this frame (one entry per line).
  final List<TerminalLineState> states;

  /// The default prompt printed before a command (`$ ` by default).
  final String prompt;

  /// The optional window chrome, or `null` for a bare terminal.
  final TerminalChrome? chrome;

  /// The colors this paints with (prompt / output / caret + chrome).
  final CodeTheme theme;

  /// The resolved (package-prefixed) monospace font family.
  final String fontFamily;

  /// The font size lines paint at; the line height is `fontSize * _lineHeight`.
  final double fontSize;

  static const double _lineHeight = 1.4;
  static const double _pad = 10;
  static const double _dotRadius = 5;
  static const double _dotGap = 8;

  /// The pixel height of one line.
  double get lineHeight => fontSize * _lineHeight;

  /// The pixel height of the chrome bar; `0` when there is no chrome.
  double get chromeHeight => chrome == null ? 0 : fontSize * 2;

  /// The color a command / output glyph paints in.
  Color get _textColor => theme.plain;

  /// The color the prompt paints in (a terminal accent).
  Color get _promptColor => theme.function;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = theme.background);
    if (chrome != null) _paintChrome(canvas, size, chrome!);
    var y = chromeHeight + _pad;
    for (var i = 0; i < lines.length; i++) {
      final state = states[i];
      if (!state.started) continue;
      _paintLine(canvas, lines[i], state, y);
      y += lineHeight;
    }
  }

  void _paintChrome(Canvas canvas, Size size, TerminalChrome chrome) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, chromeHeight),
      Paint()..color = theme.chromeColor,
    );
    if (chrome.showDots) _paintDots(canvas);
    final title = chrome.title;
    if (title != null) {
      final painter = layoutMonospaceLine(
        title,
        theme.lineNumberColor,
        fontFamily: fontFamily,
        fontSize: fontSize,
      );
      final x = (size.width - painter.width) / 2;
      painter
        ..paint(canvas, Offset(x, (chromeHeight - fontSize) / 2))
        ..dispose();
    }
  }

  void _paintDots(Canvas canvas) {
    const colors = [Color(0xFFFF5F56), Color(0xFFFFBD2E), Color(0xFF27C93F)];
    final cy = chromeHeight / 2;
    for (var i = 0; i < colors.length; i++) {
      final cx = _pad + _dotRadius + i * (_dotRadius * 2 + _dotGap);
      canvas.drawCircle(Offset(cx, cy), _dotRadius, Paint()..color = colors[i]);
    }
  }

  void _paintLine(Canvas canvas, TerminalLine line, TerminalLineState state, double y) {
    var x = _pad;
    final shown = line.text.substring(0, state.visibleGlyphs.clamp(0, line.text.length));
    if (line is TerminalCmd) {
      final promptText = line.prompt ?? prompt;
      x += _paintRun(canvas, promptText, _promptColor, x, y);
    }
    x += _paintRun(canvas, shown, _textColor, x, y);
    if (state.caretOn) _paintCaret(canvas, x, y);
  }

  /// Paints [text] at `(x, y)` in [color] and returns its measured width.
  double _paintRun(Canvas canvas, String text, Color color, double x, double y) {
    if (text.isEmpty) return 0;
    final painter = layoutMonospaceLine(text, color, fontFamily: fontFamily, fontSize: fontSize)
      ..paint(canvas, Offset(x, y));
    final width = painter.width;
    painter.dispose();
    return width;
  }

  void _paintCaret(Canvas canvas, double x, double y) {
    canvas.drawRect(Rect.fromLTWH(x, y, fontSize * 0.1, fontSize), Paint()..color = _textColor);
  }

  @override
  bool shouldRepaint(covariant TerminalPainter oldDelegate) =>
      !_sameStates(oldDelegate.states) ||
      oldDelegate.prompt != prompt ||
      oldDelegate.chrome != chrome ||
      oldDelegate.theme != theme ||
      oldDelegate.fontSize != fontSize ||
      oldDelegate.fontFamily != fontFamily ||
      !identical(oldDelegate.lines, lines);

  bool _sameStates(List<TerminalLineState> other) {
    if (other.length != states.length) return false;
    for (var i = 0; i < states.length; i++) {
      if (other[i] != states[i]) return false;
    }
    return true;
  }
}
