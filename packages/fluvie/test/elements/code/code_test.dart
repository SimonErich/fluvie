// WI-7 (D-CodeReveal/D-Focus/D-Theme): the public Code widget. Mounted under a
// 30fps video/scene scope, build reads the frame + scope + context.fluvie.code,
// highlights (cached), resolves the reveal, and paints CodePainter. The painter
// exposes its resolved model (visible glyphs, per-line opacity, highlighted
// lines, theme, caret) so the reveal/focus/highlight branches unit-test without
// a pixel readback.

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/transition/shared_element.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/code/code.dart';
import 'package:fluvie/src/elements/code/code_reveal.dart';
import 'package:fluvie/src/elements/code/render/code_painter.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/theme/fluvie_tokens.dart';
import 'package:fluvie/src/theme/fluvie_tokens_scope.dart';
import 'package:fluvie/src/timing/scene_scope.dart';
import 'package:fluvie/src/timing/video_scope.dart';

const _src = 'void main() {\n  final x = 42;\n  print(x);\n}';

/// Mounts [code] at [frame] under a 30fps scope (optionally inside a
/// [FluvieTokensScope] carrying [tokens]) and returns the resolved [CodePainter].
Future<CodePainter> _painterAt(
  WidgetTester tester,
  Code code, {
  int frame = 0,
  int sceneFrames = 120,
  FluvieTokens? tokens,
}) async {
  Widget child = SizedBox(width: 320, height: 240, child: code);
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
    find.descendant(of: find.byType(Code), matching: find.byType(CustomPaint)).first,
  );
  return paint.painter! as CodePainter;
}

void main() {
  group('Code reveal', () {
    testWidgets('instant paints all glyphs at frame 0', (tester) async {
      final painter = await _painterAt(tester, const Code(_src, language: 'dart'));
      expect(painter.visibleGlyphs, _src.length);
    });

    testWidgets('typing shows about half the glyphs at the mid frame', (tester) async {
      // 2 frames per glyph; total length L; full reveal at 2L frames. The mid
      // frame is L, where floor(L / 2) glyphs show.
      const mid = _src.length;
      final painter = await _painterAt(
        tester,
        const Code(_src, language: 'dart', reveal: CodeReveal.typing(Time.frames(2))),
        frame: mid,
      );
      expect(painter.visibleGlyphs, (mid ~/ 2).clamp(0, _src.length));
      expect(painter.visibleGlyphs, lessThan(_src.length));
      expect(painter.visibleGlyphs, greaterThan(0));
    });

    testWidgets('typing shows all glyphs at the end', (tester) async {
      final painter = await _painterAt(
        tester,
        const Code(_src, language: 'dart', reveal: CodeReveal.typing(Time.frames(2))),
        frame: 1000,
      );
      expect(painter.visibleGlyphs, _src.length);
    });

    testWidgets('lineByLine shows line 0 only at an early frame', (tester) async {
      // perLine 6 frames; at frame 3 only line 0 ("void main() {\n", 14 glyphs).
      final painter = await _painterAt(
        tester,
        const Code(_src, language: 'dart', reveal: CodeReveal.lineByLine(Time.frames(6))),
        frame: 3,
      );
      expect(painter.visibleGlyphs, 'void main() {\n'.length);
    });
  });

  group('Code focus and highlight', () {
    testWidgets('focusLines dims the other lines to dimOpacity', (tester) async {
      final painter = await _painterAt(
        tester,
        const Code(_src, language: 'dart', focusLines: {2}),
      );
      // 1-based line 2 is focused (opacity 1); the others dim.
      expect(painter.lineOpacity(1), const CodeTheme.dark().dimOpacity);
      expect(painter.lineOpacity(2), 1.0);
      expect(painter.lineOpacity(3), const CodeTheme.dark().dimOpacity);
    });

    testWidgets('no focusLines leaves every line at full opacity', (tester) async {
      final painter = await _painterAt(tester, const Code(_src, language: 'dart'));
      expect(painter.lineOpacity(1), 1.0);
      expect(painter.lineOpacity(2), 1.0);
    });

    testWidgets('highlightLines tints the line background', (tester) async {
      final painter = await _painterAt(
        tester,
        const Code(_src, language: 'dart', highlightLines: {1}),
      );
      expect(painter.isHighlighted(1), isTrue);
      expect(painter.isHighlighted(2), isFalse);
    });
  });

  group('Code theming', () {
    testWidgets('an explicit theme overrides context.fluvie.code', (tester) async {
      final painter = await _painterAt(
        tester,
        const Code(_src, language: 'dart', theme: CodeTheme.light()),
        tokens: const FluvieTokens.fallback(), // dark code by default
      );
      expect(painter.theme, const CodeTheme.light());
    });

    testWidgets('with no theme it reads context.fluvie.code', (tester) async {
      const custom = FluvieTokens(
        palette: ChartPalette([Color(0xFF6C5CE7)]),
        axisColor: Color(0xFF9E9E9E),
        gridColor: Color(0x33FFFFFF),
        labelColor: Color(0xFFE0E0E0),
        code: CodeTheme.light(),
      );
      final painter = await _painterAt(
        tester,
        const Code(_src, language: 'dart'),
        tokens: custom,
      );
      expect(painter.theme, const CodeTheme.light());
    });

    testWidgets('with no scope it falls back to CodeTheme.dark()', (tester) async {
      final painter = await _painterAt(tester, const Code(_src, language: 'dart'));
      expect(painter.theme, const CodeTheme.dark());
    });
  });

  group('Code structure', () {
    testWidgets('carries its content fields and defaults', (tester) async {
      const code = Code(_src);
      expect(code.source, _src);
      expect(code.language, 'plaintext');
      expect(code.reveal, CodeReveal.instant);
      expect(code.focusLines, isNull);
      expect(code.highlightLines, isNull);
    });

    testWidgets('an explicit style sets the painter font family and size', (tester) async {
      final painter = await _painterAt(
        tester,
        const Code(
          _src,
          language: 'dart',
          style: TextStyle(fontFamily: 'Courier', fontSize: 20),
        ),
      );
      expect(painter.fontFamily, 'Courier');
      expect(painter.fontSize, 20);
    });

    testWidgets('with no style it defaults to the bundled mono font', (tester) async {
      final painter = await _painterAt(tester, const Code(_src, language: 'dart'));
      expect(painter.fontFamily, Code.defaultFontFamily);
      expect(painter.fontSize, 14);
    });

    testWidgets('shared wraps the result in a SharedElement', (tester) async {
      final anchor = Anchor('code');
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
                  width: 320,
                  height: 240,
                  child: Code(_src, language: 'dart', shared: anchor),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(SharedElement), findsOneWidget);
    });

    testWidgets('without shared it mounts no SharedElement', (tester) async {
      await _painterAt(tester, const Code(_src, language: 'dart'));
      expect(find.byType(SharedElement), findsNothing);
    });
  });

  group('CodePainter shouldRepaint', () {
    testWidgets('repaints when the visible-glyph cutoff differs', (tester) async {
      final early = await _painterAt(
        tester,
        const Code(_src, language: 'dart', reveal: CodeReveal.typing(Time.frames(2))),
        frame: 4,
      );
      final later = await _painterAt(
        tester,
        const Code(_src, language: 'dart', reveal: CodeReveal.typing(Time.frames(2))),
        frame: 20,
      );
      expect(later.shouldRepaint(early), isTrue);
    });

    testWidgets('does not repaint when nothing changed', (tester) async {
      final a = await _painterAt(tester, const Code(_src, language: 'dart'));
      final b = await _painterAt(tester, const Code(_src, language: 'dart'));
      // Same content hash -> same cached lines (identical) -> no repaint.
      expect(b.shouldRepaint(a), isFalse);
    });

    testWidgets('repaints when the theme differs', (tester) async {
      final dark = await _painterAt(tester, const Code(_src, language: 'dart'));
      final light = await _painterAt(
        tester,
        const Code(_src, language: 'dart', theme: CodeTheme.light()),
      );
      expect(light.shouldRepaint(dark), isTrue);
    });

    testWidgets('repaints when the focus set differs', (tester) async {
      final none = await _painterAt(tester, const Code(_src, language: 'dart'));
      final focused = await _painterAt(
        tester,
        const Code(_src, language: 'dart', focusLines: {1}),
      );
      expect(focused.shouldRepaint(none), isTrue);
    });
  });

  group('CodePainter caret', () {
    testWidgets('a typing reveal lights a caret at frame 0', (tester) async {
      final painter = await _painterAt(
        tester,
        const Code(_src, language: 'dart', reveal: CodeReveal.typing(Time.frames(2))),
      );
      expect(painter.caretOn, isTrue);
    });

    testWidgets('an instant reveal shows no caret', (tester) async {
      final painter = await _painterAt(tester, const Code(_src, language: 'dart'));
      expect(painter.caretOn, isFalse);
    });
  });
}
