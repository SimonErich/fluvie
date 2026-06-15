import 'package:flutter/widgets.dart'
    show BuildContext, CustomPaint, StatelessWidget, TextStyle, Widget;
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/elements/code/code_reveal.dart';
import 'package:fluvie/src/elements/code/diff/diff_geometry.dart';
import 'package:fluvie/src/elements/code/diff/diff_op.dart';
import 'package:fluvie/src/elements/code/diff/line_diff.dart';
import 'package:fluvie/src/elements/code/highlight/highlight_cache.dart';
import 'package:fluvie/src/elements/code/highlight/highlight_js_highlighter.dart';
import 'package:fluvie/src/elements/code/highlight/syntax_highlighter.dart';
import 'package:fluvie/src/elements/code/render/code_layout.dart';
import 'package:fluvie/src/elements/code/render/code_painter.dart';
import 'package:fluvie/src/elements/code/render/diff_painter.dart';
import 'package:fluvie/src/elements/code/theme/code_theme.dart';
import 'package:fluvie/src/elements/reveal/reveal_progress.dart';
import 'package:fluvie/src/elements/runtime/element_shared.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/theme/build_context_tokens.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

part 'code_internals.dart';

/// Renders syntax-highlighted source as a frame-driven element — an intrinsic
/// widget whose constructor takes content behaviour only.
///
/// The source is highlighted **once** per content (cached by content hash) and
/// the painter is a pure function of `(parsed spans, reveal progress, theme
/// tokens)`, so the same frame renders byte-identically every time. [reveal]
/// drives how the code appears: [CodeReveal.instant]
/// shows everything, [CodeReveal.typing] reveals it glyph by glyph (sharing the
/// `Typewriter` arithmetic), and [CodeReveal.lineByLine] reveals whole lines in
/// sequence.
///
/// ```dart
/// Code(
///   'void main() => print("hi");',
///   language: 'dart',
///   reveal: CodeReveal.typing(2.frames),
///   focusLines: {1},
/// );
/// ```
///
/// [focusLines] (1-based) dims every other line to the theme's `dimOpacity`;
/// [highlightLines] tints those lines' backgrounds. Both are content params, so
/// the frame clock and scene placement drive which focus is active — swap the
/// sets across scenes (or cross-fade with `.animate([Animation.fadeIn()])`).
/// Colors come from [theme] when given, else `context.fluvie.code`. Transforms
/// and effects ride `.animate()`; [shared] wraps the result in a `SharedElement`
/// for a hero morph across a scene boundary.
final class Code extends StatelessWidget {
  /// Renders [source] in [language] (default `'plaintext'`), revealed by
  /// [reveal], focused / highlighted by [focusLines] / [highlightLines], colored
  /// by [theme] (or `context.fluvie.code`), in [style].
  const Code(
    this.source, {
    this.language = 'plaintext',
    this.theme,
    this.reveal = CodeReveal.instant,
    this.focusLines,
    this.highlightLines,
    this.style,
    this.shared,
    super.key,
  }) : after = null,
       _kind = _CodeKind.highlight;

  /// Renders an animated line diff from [before] to [after].
  ///
  /// Both sides are highlighted once (cached by content hash) and the line-level
  /// LCS diff drives the motion over the element window: removed lines fade out
  /// and collapse with a red gutter, inserted lines fade in and expand with a
  /// green gutter, and kept lines slide to their new vertical position. The
  /// motion runs across [reveal] (a [CodeReveal]; `instant` shows the finished
  /// `after` document, a timed reveal animates it). [theme] (or
  /// `context.fluvie.code`) colors both sides; [shared] hero-morphs the result.
  ///
  /// ```dart
  /// Code.diff(
  ///   'final x = 1;',
  ///   'final x = 2;',
  ///   language: 'dart',
  ///   reveal: CodeReveal.lineByLine(12.frames),
  /// );
  /// ```
  const Code.diff(
    String before,
    this.after, {
    this.language = 'plaintext',
    this.theme,
    this.reveal = CodeReveal.instant,
    this.style,
    this.shared,
    super.key,
  }) : source = before,
       focusLines = null,
       highlightLines = null,
       _kind = _CodeKind.diff;

  /// The full source text this element highlights and reveals. For a
  /// [Code.diff] this is the `before` document.
  final String source;

  /// The `after` document for a [Code.diff], or `null` for a plain `Code`.
  final String? after;

  /// Whether this is a plain highlight or an animated diff.
  final _CodeKind _kind;

  /// The highlight.js language id (`'dart'`, `'python'`, …); an unknown id
  /// renders the source as plain, unhighlighted text.
  final String language;

  /// The colors to paint with, or `null` to read `context.fluvie.code`.
  final CodeTheme? theme;

  /// How the source appears over the element window; defaults to
  /// [CodeReveal.instant].
  final CodeReveal reveal;

  /// The 1-based line numbers to keep lit; when non-null every other line dims.
  /// `null` keeps all lines at full opacity.
  final Set<int>? focusLines;

  /// The 1-based line numbers whose background is tinted; `null` tints nothing.
  final Set<int>? highlightLines;

  /// The base text style; only its `fontSize` and `fontFamily` are read (a
  /// `null` family defaults to the bundled JetBrains Mono). Colors come from the
  /// [theme]. `null` uses the element defaults.
  final TextStyle? style;

  /// An optional hero anchor: when non-null the code morphs across the boundary
  /// it shares with the same anchor in the adjacent scene.
  final Anchor? shared;

  /// The highlighter every `Code` tokenizes through; the default is the
  /// highlight.js-backed [HighlightJsHighlighter].
  static const SyntaxHighlighter highlighter = HighlightJsHighlighter();

  /// The bundled monospace font family `Code` defaults to.
  static const String defaultFontFamily = 'packages/fluvie/JetBrains Mono';

  @override
  Widget build(BuildContext context) {
    final frame = FrameProvider.of(context).frame;
    final scope = TimeScopeProvider.of(context);
    final resolvedTheme = theme ?? context.fluvie.code;
    final painter = switch (_kind) {
      _CodeKind.highlight => _buildCodePainter(
        source: source,
        language: language,
        reveal: reveal,
        focusLines: focusLines,
        highlightLines: highlightLines,
        theme: resolvedTheme,
        style: style,
        elapsed: frame - scope.startFrame,
        scope: scope,
      ),
      _CodeKind.diff => _buildDiffPainter(
        before: source,
        after: after!,
        language: language,
        reveal: reveal,
        theme: resolvedTheme,
        style: style,
        frame: frame,
        scope: scope,
      ),
    };
    final visible = CustomPaint(painter: painter);
    return wrapShared(shared, visible);
  }
}
