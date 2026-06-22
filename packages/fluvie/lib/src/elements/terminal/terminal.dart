import 'package:flutter/widgets.dart'
    show BuildContext, CustomPaint, StatelessWidget, TextStyle, Widget;
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/runtime/element_shared.dart';
import 'package:fluvie/src/elements/terminal/render/terminal_layout.dart';
import 'package:fluvie/src/elements/terminal/render/terminal_painter.dart';
import 'package:fluvie/src/elements/terminal/terminal_chrome.dart';
import 'package:fluvie/src/elements/terminal/terminal_line.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/theme/build_context_tokens.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

/// The default font size `Terminal` paints at when [Terminal.style] gives none.
const double _defaultFontSize = 14;

/// Renders a terminal session as a frame-driven element — an intrinsic widget
/// whose constructor takes content behaviour only.
///
/// The [lines] play in sequence: a [TerminalLine.cmd]
/// types its text glyph by glyph after a [prompt] with a blinking caret, and a
/// [TerminalLine.out] streams its output whole once its turn arrives. Each line
/// starts [lineGap] after the previous one settles, and a command types at
/// [typingSpeed] frames per glyph. The painter is a pure function of
/// `(lines, reveal state, theme tokens)`, so the same frame renders the same
/// every time.
///
/// ```dart
/// Terminal(
///   chrome: TerminalChrome.macos(title: 'zsh'),
///   lines: [
///     TerminalLine.cmd('npm install'),
///     TerminalLine.out('added 120 packages'),
///   ],
/// );
/// ```
///
/// [chrome] adds an optional window bar (off by default). Colors come from
/// `context.fluvie.code`. Transforms and effects ride `.animate()`; [shared]
/// wraps the result in a `SharedElement` for a hero morph across a scene
/// boundary.
final class Terminal extends StatelessWidget {
  /// Renders [lines] in sequence, each command prefixed by [prompt] (default
  /// `$ `), typed at [typingSpeed], spaced by [lineGap], with optional [chrome]
  /// and [style].
  const Terminal({
    required this.lines,
    this.prompt = r'$ ',
    this.chrome,
    this.typingSpeed = const Time.frames(2),
    this.lineGap = const Time.frames(18),
    this.style,
    this.shared,
    super.key,
  });

  /// The terminal lines, in order; commands type, output streams.
  final List<TerminalLine> lines;

  /// The prompt printed before every command line, unless a line overrides it.
  final String prompt;

  /// The optional window chrome, or `null` for a bare terminal.
  final TerminalChrome? chrome;

  /// How long each command glyph takes to appear; resolved against the element
  /// window so a relative speed scales with the scene.
  final Time typingSpeed;

  /// How long after one line settles the next begins; resolved against the
  /// window.
  final Time lineGap;

  /// The base text style; only its `fontSize` and `fontFamily` are read (a
  /// `null` family defaults to the bundled JetBrains Mono). Colors come from
  /// `context.fluvie.code`. `null` uses the element defaults.
  final TextStyle? style;

  /// An optional hero anchor: when non-null the terminal morphs across the
  /// boundary it shares with the same anchor in the adjacent scene. `null`
  /// mounts no `SharedElement`.
  final Anchor? shared;

  /// The bundled monospace font family `Terminal` defaults to.
  static const String defaultFontFamily = 'packages/fluvie/JetBrains Mono';

  @override
  Widget build(BuildContext context) {
    final frame = FrameProvider.of(context).frame;
    final scope = TimeScopeProvider.of(context);
    final states = terminalReveal(
      lines: lines,
      elapsed: frame - scope.startFrame,
      typingSpeed: typingSpeed,
      lineGap: lineGap,
      scope: scope,
    );
    final visible = CustomPaint(
      painter: TerminalPainter(
        lines: lines,
        states: states,
        prompt: prompt,
        chrome: chrome,
        theme: context.fluvie.code,
        fontFamily: style?.fontFamily ?? defaultFontFamily,
        fontSize: style?.fontSize ?? _defaultFontSize,
      ),
    );
    return wrapShared(shared, visible);
  }
}
