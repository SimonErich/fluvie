import 'package:flutter/painting.dart' show Color;
import 'package:fluvie/src/elements/code/highlight/token_style.dart';
import 'package:meta/meta.dart' show immutable;

/// The colors a `Code` (and `Terminal`) element paints with.
///
/// A `CodeTheme` maps every [TokenStyle] to a color via [colorFor] and carries
/// the editor chrome: the [background], the [gutterColor] and [lineNumberColor]
/// of the line-number gutter, the [highlightColor] tinting a highlighted line's
/// background, the [dimOpacity] non-focused lines fade to, and the [chromeColor]
/// for a terminal window bar. It is part of `FluvieTokens` (read via
/// `context.fluvie.code`), with a `Code(theme:)` override winning locally.
///
/// `@immutable` and value-equal by field, so two builds of the same theme color
/// identically and the highlight / repaint caches stay frame-stable. Ship
/// [CodeTheme.dark] / [CodeTheme.light] presets, or build a custom theme.
///
/// ```dart
/// const Code('void main() {}', language: 'dart', theme: CodeTheme.light());
/// ```
@immutable
final class CodeTheme {
  /// Creates a theme from explicit per-token colors and editor chrome colors.
  // coverage:ignore-line const ctor artifact palette pinned by code_theme_test
  const CodeTheme({
    required this.keyword,
    required this.string,
    required this.comment,
    required this.number,
    required this.type,
    required this.function,
    required this.punctuation,
    required this.plain,
    required this.background,
    required this.gutterColor,
    required this.lineNumberColor,
    required this.highlightColor,
    required this.chromeColor,
    required this.dimOpacity,
    this.addedGutter = const Color(0xFF4EC9B0),
    this.removedGutter = const Color(0xFFF14C4C),
  });

  /// A neutral dark theme: light text on a near-black editor background.
  const CodeTheme.dark()
    : keyword = const Color(0xFFC586C0),
      string = const Color(0xFFCE9178),
      comment = const Color(0xFF6A9955),
      number = const Color(0xFFB5CEA8),
      type = const Color(0xFF4EC9B0),
      function = const Color(0xFFDCDCAA),
      punctuation = const Color(0xFFD4D4D4),
      plain = const Color(0xFFD4D4D4),
      background = const Color(0xFF1E1E1E),
      gutterColor = const Color(0xFF252526),
      lineNumberColor = const Color(0xFF858585),
      highlightColor = const Color(0x33FFFFFF),
      chromeColor = const Color(0xFF323233),
      dimOpacity = 0.3,
      addedGutter = const Color(0xFF487E02),
      removedGutter = const Color(0xFF8A1F11);

  /// A neutral light theme: dark text on a near-white editor background.
  // coverage:ignore-line const ctor artifact palette pinned by code_theme_test
  const CodeTheme.light()
    : keyword = const Color(0xFFAF00DB),
      string = const Color(0xFFA31515),
      comment = const Color(0xFF008000),
      number = const Color(0xFF098658),
      type = const Color(0xFF267F99),
      function = const Color(0xFF795E26),
      punctuation = const Color(0xFF000000),
      plain = const Color(0xFF000000),
      background = const Color(0xFFFFFFFF),
      gutterColor = const Color(0xFFF3F3F3),
      lineNumberColor = const Color(0xFF237893),
      highlightColor = const Color(0x14000000),
      chromeColor = const Color(0xFFDDDDDD),
      dimOpacity = 0.35,
      addedGutter = const Color(0xFF22863A),
      removedGutter = const Color(0xFFCB2431);

  /// The color of [TokenStyle.keyword] tokens.
  final Color keyword;

  /// The color of [TokenStyle.string] tokens.
  final Color string;

  /// The color of [TokenStyle.comment] tokens.
  final Color comment;

  /// The color of [TokenStyle.number] tokens.
  final Color number;

  /// The color of [TokenStyle.type] tokens.
  final Color type;

  /// The color of [TokenStyle.function] tokens.
  final Color function;

  /// The color of [TokenStyle.punctuation] tokens.
  final Color punctuation;

  /// The color of [TokenStyle.plain] tokens (and the default text color).
  final Color plain;

  /// The editor background painted behind the code.
  final Color background;

  /// The background of the line-number gutter.
  final Color gutterColor;

  /// The color of the line numbers in the gutter.
  final Color lineNumberColor;

  /// The background tint painted behind a highlighted line.
  final Color highlightColor;

  /// The chrome color for a terminal window bar.
  final Color chromeColor;

  /// The opacity (`0..1`) a non-focused line fades to when `focusLines` is set.
  final double dimOpacity;

  /// The gutter color marking an inserted line in a `Code.diff` (the green
  /// stripe down the left of an added line).
  final Color addedGutter;

  /// The gutter color marking a removed line in a `Code.diff` (the red stripe
  /// down the left of a deleted line).
  final Color removedGutter;

  /// The color for [style], so the painter never branches on the token kind.
  Color colorFor(TokenStyle style) => switch (style) {
    TokenStyle.keyword => keyword,
    TokenStyle.string => string,
    TokenStyle.comment => comment,
    TokenStyle.number => number,
    TokenStyle.type => type,
    TokenStyle.function => function,
    TokenStyle.punctuation => punctuation,
    TokenStyle.plain => plain,
  };

  @override
  bool operator ==(Object other) =>
      other is CodeTheme &&
      other.keyword == keyword &&
      other.string == string &&
      other.comment == comment &&
      other.number == number &&
      other.type == type &&
      other.function == function &&
      other.punctuation == punctuation &&
      other.plain == plain &&
      other.background == background &&
      other.gutterColor == gutterColor &&
      other.lineNumberColor == lineNumberColor &&
      other.highlightColor == highlightColor &&
      other.chromeColor == chromeColor &&
      other.dimOpacity == dimOpacity &&
      other.addedGutter == addedGutter &&
      other.removedGutter == removedGutter;

  @override
  int get hashCode => Object.hashAll([
    CodeTheme,
    keyword,
    string,
    comment,
    number,
    type,
    function,
    punctuation,
    plain,
    background,
    gutterColor,
    lineNumberColor,
    highlightColor,
    chromeColor,
    dimOpacity,
    addedGutter,
    removedGutter,
  ]);

  @override
  String toString() => 'CodeTheme(background: $background, plain: $plain)';
}
