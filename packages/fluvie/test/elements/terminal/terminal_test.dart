// WI-14 (D-LineModel/D-Chrome/D-Theme): the public Terminal widget. Mounted
// under a 30fps video/scene scope, build reads the frame + scope +
// context.fluvie.code, computes terminalReveal, and paints TerminalPainter. The
// painter exposes its resolved model (the per-line states, prompt, chrome,
// theme, caret) so the reveal/chrome branches unit-test without a pixel readback.

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/transition/shared_element.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/terminal/render/terminal_painter.dart';
import 'package:fluvie/src/elements/terminal/terminal.dart';
import 'package:fluvie/src/elements/terminal/terminal_chrome.dart';
import 'package:fluvie/src/elements/terminal/terminal_line.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/theme/fluvie_tokens.dart';
import 'package:fluvie/src/theme/fluvie_tokens_scope.dart';
import 'package:fluvie/src/timing/scene_scope.dart';
import 'package:fluvie/src/timing/video_scope.dart';

const _lines = [
  TerminalLine.cmd('npm i'),
  TerminalLine.out('added 120 packages'),
];

/// Mounts [terminal] at [frame] under a 30fps scope (optionally inside a
/// [FluvieTokensScope] carrying [tokens]) and returns the resolved
/// [TerminalPainter].
Future<TerminalPainter> _painterAt(
  WidgetTester tester,
  Terminal terminal, {
  int frame = 0,
  int sceneFrames = 600,
  FluvieTokens? tokens,
}) async {
  Widget child = SizedBox(width: 360, height: 200, child: terminal);
  if (tokens != null) child = FluvieTokensScope(tokens: tokens, child: child);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RenderControllerScope(
        controller: RenderController(initialFrame: frame),
        child: VideoScope(
          fps: 30,
          duration: Time.frames(sceneFrames),
          child: SceneScope(duration: Time.frames(sceneFrames), child: child),
        ),
      ),
    ),
  );
  final paint = tester.widget<CustomPaint>(
    find.descendant(of: find.byType(Terminal), matching: find.byType(CustomPaint)).first,
  );
  return paint.painter! as TerminalPainter;
}

void main() {
  group('Terminal sequence', () {
    testWidgets('early frame shows the prompt and a few typed glyphs of line 0', (tester) async {
      // 2 frames/glyph (default); at frame 4 -> 2 glyphs of "npm i", with a caret.
      final painter = await _painterAt(
        tester,
        const Terminal(lines: _lines),
        frame: 4,
      );
      expect(painter.states[0].started, isTrue);
      expect(painter.states[0].visibleGlyphs, 2);
      expect(painter.states[0].caretOn, isTrue);
      // line 1 (the output) has not streamed in yet.
      expect(painter.states[1].started, isFalse);
    });

    testWidgets('later frame settles line 0 and streams line 1 in', (tester) async {
      final painter = await _painterAt(
        tester,
        const Terminal(lines: _lines, lineGap: Time.frames(12)),
        frame: 200,
      );
      expect(painter.states[0].visibleGlyphs, 'npm i'.length);
      expect(painter.states[0].caretOn, isFalse);
      expect(painter.states[1].started, isTrue);
      expect(painter.states[1].visibleGlyphs, 'added 120 packages'.length);
    });
  });

  group('Terminal prompt', () {
    testWidgets(r'defaults the prompt to "$ "', (tester) async {
      final painter = await _painterAt(tester, const Terminal(lines: _lines));
      expect(painter.prompt, r'$ ');
    });

    testWidgets('a configurable prompt is carried to the painter', (tester) async {
      final painter = await _painterAt(
        tester,
        const Terminal(lines: _lines, prompt: '> '),
      );
      expect(painter.prompt, '> ');
    });
  });

  group('Terminal chrome', () {
    testWidgets('no chrome by default', (tester) async {
      final painter = await _painterAt(tester, const Terminal(lines: _lines));
      expect(painter.chrome, isNull);
    });

    testWidgets('macos chrome carries the window bar and dots', (tester) async {
      final painter = await _painterAt(
        tester,
        const Terminal(
          lines: _lines,
          chrome: TerminalChrome.macos(title: 'zsh'),
        ),
      );
      expect(painter.chrome, const TerminalChrome.macos(title: 'zsh'));
      expect(painter.chrome!.showDots, isTrue);
    });
  });

  group('Terminal theming', () {
    testWidgets('reads colors from context.fluvie.code', (tester) async {
      const custom = FluvieTokens(
        palette: ChartPalette([Color(0xFF6C5CE7)]),
        axisColor: Color(0xFF9E9E9E),
        gridColor: Color(0x33FFFFFF),
        labelColor: Color(0xFFE0E0E0),
        code: CodeTheme.light(),
      );
      final painter = await _painterAt(tester, const Terminal(lines: _lines), tokens: custom);
      expect(painter.theme, const CodeTheme.light());
    });

    testWidgets('falls back to CodeTheme.dark() with no scope', (tester) async {
      final painter = await _painterAt(tester, const Terminal(lines: _lines));
      expect(painter.theme, const CodeTheme.dark());
    });
  });

  group('Terminal structure', () {
    testWidgets('carries its content fields and defaults', (tester) async {
      const terminal = Terminal(lines: _lines);
      expect(terminal.lines, _lines);
      expect(terminal.prompt, r'$ ');
      expect(terminal.chrome, isNull);
    });

    testWidgets('defaults to the bundled mono font', (tester) async {
      final painter = await _painterAt(tester, const Terminal(lines: _lines));
      expect(painter.fontFamily, Terminal.defaultFontFamily);
      expect(painter.fontSize, 14);
    });

    testWidgets('an explicit style sets the painter font family and size', (tester) async {
      final painter = await _painterAt(
        tester,
        const Terminal(
          lines: _lines,
          style: TextStyle(fontFamily: 'Courier', fontSize: 18),
        ),
      );
      expect(painter.fontFamily, 'Courier');
      expect(painter.fontSize, 18);
    });

    testWidgets('shared wraps the result in a SharedElement', (tester) async {
      final anchor = Anchor('terminal');
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RenderControllerScope(
            controller: RenderController(),
            child: VideoScope(
              fps: 30,
              duration: const Time.frames(120),
              child: SceneScope(
                duration: const Time.frames(120),
                child: SizedBox(
                  width: 360,
                  height: 200,
                  child: Terminal(lines: _lines, shared: anchor),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(SharedElement), findsOneWidget);
    });

    testWidgets('without shared it mounts no SharedElement', (tester) async {
      await _painterAt(tester, const Terminal(lines: _lines));
      expect(find.byType(SharedElement), findsNothing);
    });
  });

  group('TerminalPainter shouldRepaint', () {
    testWidgets('repaints when the reveal state differs', (tester) async {
      final early = await _painterAt(
        tester,
        const Terminal(lines: _lines),
        frame: 2,
      );
      final later = await _painterAt(
        tester,
        const Terminal(lines: _lines),
        frame: 20,
      );
      expect(later.shouldRepaint(early), isTrue);
    });

    testWidgets('does not repaint when nothing changed', (tester) async {
      final a = await _painterAt(tester, const Terminal(lines: _lines));
      final b = await _painterAt(tester, const Terminal(lines: _lines));
      expect(b.shouldRepaint(a), isFalse);
    });

    testWidgets('repaints when the theme differs', (tester) async {
      final dark = await _painterAt(tester, const Terminal(lines: _lines));
      const custom = FluvieTokens(
        palette: ChartPalette([Color(0xFF6C5CE7)]),
        axisColor: Color(0xFF9E9E9E),
        gridColor: Color(0x33FFFFFF),
        labelColor: Color(0xFFE0E0E0),
        code: CodeTheme.light(),
      );
      final light = await _painterAt(tester, const Terminal(lines: _lines), tokens: custom);
      expect(light.shouldRepaint(dark), isTrue);
    });

    testWidgets('repaints when the chrome differs', (tester) async {
      final bare = await _painterAt(tester, const Terminal(lines: _lines));
      final chromed = await _painterAt(
        tester,
        const Terminal(
          lines: _lines,
          chrome: TerminalChrome.macos(title: 'zsh'),
        ),
      );
      expect(chromed.shouldRepaint(bare), isTrue);
    });
  });

  group('TerminalPainter paint', () {
    /// Records [painter] onto a recording canvas to exercise the paint branches.
    void paint(TerminalPainter painter) {
      final recorder = ui.PictureRecorder();
      painter.paint(ui.Canvas(recorder), const Size(360, 200));
      recorder.endRecording().dispose();
    }

    testWidgets('paints a mid-typing command with a caret (no chrome)', (tester) async {
      final painter = await _painterAt(
        tester,
        const Terminal(lines: _lines),
        frame: 4,
      );
      expect(painter.chrome, isNull);
      expect(painter.states[0].caretOn, isTrue);
      paint(painter);
    });

    testWidgets('paints a settled command and a streamed output line', (tester) async {
      final painter = await _painterAt(
        tester,
        const Terminal(lines: _lines, lineGap: Time.frames(12)),
        frame: 200,
      );
      expect(painter.states[1].started, isTrue);
      paint(painter);
    });

    testWidgets('paints the window chrome with a title and the dots', (tester) async {
      final painter = await _painterAt(
        tester,
        const Terminal(
          lines: _lines,
          chrome: TerminalChrome.macos(title: 'zsh'),
        ),
        frame: 200,
      );
      expect(painter.chrome!.title, 'zsh');
      paint(painter);
    });

    testWidgets('paints chrome with no title and no dots (none)', (tester) async {
      final painter = await _painterAt(
        tester,
        const Terminal(lines: _lines, chrome: TerminalChrome.none),
        frame: 200,
      );
      expect(painter.chrome!.showDots, isFalse);
      expect(painter.chrome!.title, isNull);
      paint(painter);
    });

    testWidgets('paints a per-line prompt override', (tester) async {
      final painter = await _painterAt(
        tester,
        const Terminal(lines: [TerminalLine.cmd('deploy', prompt: '~> ')]),
        frame: 200,
      );
      paint(painter);
    });
  });
}
