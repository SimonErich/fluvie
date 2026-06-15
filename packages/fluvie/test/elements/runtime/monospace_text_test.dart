// DRY 2.1: the shared monospace TextPainter helper extracted from CodePainter,
// TerminalPainter, and DiffPainter. Asserts the laid-out painter carries the
// requested font family / size / direction, that opacity rides the color alpha
// (color.withValues(alpha: opacity)), and that the default opacity is fully
// opaque. Pure unit coverage — the byte-identical pixel proof lives in the three
// painters' goldens, which must pass unchanged.

import 'dart:ui' show Color, TextDirection;

import 'package:flutter/painting.dart' show TextHeightBehavior, TextPainter, TextSpan, TextStyle;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/elements/runtime/monospace_text.dart';

const _family = 'packages/fluvie/JetBrains Mono';
const _color = Color(0xFF1133AA);

TextStyle _styleOf(TextPainter painter) {
  final span = painter.text! as TextSpan;
  return span.style!;
}

void main() {
  test('lays out the requested text with the monospace font family and size', () {
    final painter = layoutMonospaceLine('abc', _color, fontFamily: _family, fontSize: 18);
    final span = painter.text! as TextSpan;
    expect(span.text, 'abc');
    final style = _styleOf(painter);
    expect(style.fontFamily, _family);
    expect(style.fontSize, 18);
    painter.dispose();
  });

  test('lays out left-to-right and returns an already-measured painter', () {
    final painter = layoutMonospaceLine('w', _color, fontFamily: _family, fontSize: 14);
    expect(painter.textDirection, TextDirection.ltr);
    // A laid-out painter exposes a finite, non-negative width without re-layout.
    expect(painter.width, greaterThanOrEqualTo(0));
    painter.dispose();
  });

  test('default opacity keeps the color fully opaque', () {
    final painter = layoutMonospaceLine('x', _color, fontFamily: _family, fontSize: 14);
    expect(_styleOf(painter).color, _color.withValues(alpha: 1));
    painter.dispose();
  });

  test('opacity rides the color alpha (color.withValues(alpha: opacity))', () {
    final painter = layoutMonospaceLine(
      'x',
      _color,
      fontFamily: _family,
      fontSize: 14,
      opacity: 0.4,
    );
    expect(_styleOf(painter).color, _color.withValues(alpha: 0.4));
    painter.dispose();
  });

  test('carries a default TextHeightBehavior (no per-line height clamping)', () {
    final painter = layoutMonospaceLine('x', _color, fontFamily: _family, fontSize: 14);
    expect(painter.textHeightBehavior, const TextHeightBehavior());
    painter.dispose();
  });
}
