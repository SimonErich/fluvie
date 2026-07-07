// WI-10 (D-Diff): the Code.diff factory and its _DiffPainter, mounted under a
// 30fps video/scene scope. build highlights both sides (cached), diffs them,
// resolves the reveal progress, lays out the ops, and paints. The painter
// exposes its resolved diff lines (text, opacity, gutter color) and both
// highlighted sides so the add / remove / change / slide branches unit-test
// without a pixel readback.

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/transition/shared_element.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/code/code.dart';
import 'package:fluvie/src/elements/code/code_reveal.dart';
import 'package:fluvie/src/elements/code/render/diff_painter.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/theme/fluvie_tokens.dart';
import 'package:fluvie/src/theme/fluvie_tokens_scope.dart';
import 'package:fluvie/src/timing/scene_scope.dart';
import 'package:fluvie/src/timing/video_scope.dart';

const _before = 'final x = 1;\nprint(x);';
const _after = 'final x = 2;\nprint(x);';

/// Mounts [code] at [frame] under a 30fps scope and returns its [DiffPainter].
Future<DiffPainter> _diffAt(
  WidgetTester tester,
  Code code, {
  int frame = 0,
  int sceneFrames = 120,
  FluvieTokens? tokens,
}) async {
  Widget child = SizedBox(width: 360, height: 200, child: code);
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
  return paint.painter! as DiffPainter;
}

void main() {
  group('Code.diff progress endpoints', () {
    testWidgets('at progress 0 every before line is visible at full height', (tester) async {
      final painter = await _diffAt(
        tester,
        const Code.diff(
          _before,
          _after,
          language: 'dart',
          reveal: CodeReveal.lineByLine(Time.frames(10)),
        ),
      );
      // The removed line ("final x = 1;") is fully opaque; the inserted line
      // ("final x = 2;") is collapsed.
      final removed = painter.lines.firstWhere((l) => l.text == 'final x = 1;');
      final inserted = painter.lines.firstWhere((l) => l.text == 'final x = 2;');
      expect(removed.opacity, 1.0);
      expect(removed.heightFactor, 1.0);
      expect(inserted.opacity, 0.0);
      expect(inserted.heightFactor, 0.0);
    });

    testWidgets('at progress 1 every after line is visible at full height', (tester) async {
      final painter = await _diffAt(
        tester,
        const Code.diff(
          _before,
          _after,
          language: 'dart',
          reveal: CodeReveal.lineByLine(Time.frames(1)),
        ),
        frame: 1000,
      );
      final removed = painter.lines.firstWhere((l) => l.text == 'final x = 1;');
      final inserted = painter.lines.firstWhere((l) => l.text == 'final x = 2;');
      expect(removed.opacity, 0.0);
      expect(removed.heightFactor, 0.0);
      expect(inserted.opacity, 1.0);
      expect(inserted.heightFactor, 1.0);
    });
  });

  group('Code.diff mid-progress motion', () {
    testWidgets('a Remove line fades and collapses with a red gutter', (tester) async {
      final painter = await _diffAtMid(tester);
      final removed = painter.lines.firstWhere((l) => l.text == 'final x = 1;');
      expect(removed.opacity, greaterThan(0.0));
      expect(removed.opacity, lessThan(1.0));
      expect(removed.heightFactor, lessThan(1.0));
      expect(removed.gutter, const CodeTheme.dark().removedGutter);
    });

    testWidgets('an Insert line fades in and expands with a green gutter', (tester) async {
      final painter = await _diffAtMid(tester);
      final inserted = painter.lines.firstWhere((l) => l.text == 'final x = 2;');
      expect(inserted.opacity, greaterThan(0.0));
      expect(inserted.opacity, lessThan(1.0));
      expect(inserted.heightFactor, greaterThan(0.0));
      expect(inserted.gutter, const CodeTheme.dark().addedGutter);
    });

    testWidgets('a Keep line stays lit and slides toward its new y', (tester) async {
      final painter = await _diffAtMid(tester);
      final kept = painter.lines.firstWhere((l) => l.text == 'print(x);');
      expect(kept.opacity, 1.0);
      expect(kept.gutter, isNull);
      // The kept line sits below the partially-collapsed remove + insert above
      // it, so its y is between the before-position (line 1) and after-position.
      expect(kept.y, greaterThan(0.0));
    });
  });

  group('Code.diff highlighting and theming', () {
    testWidgets('both sides are highlighted (the removed line is tokenized)', (tester) async {
      final painter = await _diffAt(tester, const Code.diff(_before, _after, language: 'dart'));
      // The removed line "final x = 1;" highlights to more than one token kind
      // (keyword "final" + the rest), proving both sides ran through the cache.
      final removedTokens = painter.tokensFor('final x = 1;');
      expect(removedTokens.length, greaterThan(1));
    });

    testWidgets('an explicit theme overrides context.fluvie.code', (tester) async {
      final painter = await _diffAt(
        tester,
        const Code.diff(_before, _after, language: 'dart', theme: CodeTheme.light()),
        tokens: const FluvieTokens.fallback(),
      );
      expect(painter.theme, const CodeTheme.light());
    });

    testWidgets('with a scope it reads context.fluvie.code', (tester) async {
      const custom = FluvieTokens(
        palette: ChartPalette([Color(0xFF6C5CE7)]),
        axisColor: Color(0xFF9E9E9E),
        gridColor: Color(0x33FFFFFF),
        labelColor: Color(0xFFE0E0E0),
        code: CodeTheme.light(),
      );
      final painter = await _diffAt(
        tester,
        const Code.diff(_before, _after, language: 'dart'),
        tokens: custom,
      );
      expect(painter.theme, const CodeTheme.light());
    });

    testWidgets('tokensFor a line that is not in the diff is empty', (tester) async {
      final painter = await _diffAt(tester, const Code.diff(_before, _after, language: 'dart'));
      expect(painter.tokensFor('not a line'), isEmpty);
    });

    testWidgets('an empty before diffs to all-inserted lines', (tester) async {
      final painter = await _diffAt(
        tester,
        const Code.diff('', 'a = 1;\nb = 2;', language: 'dart'),
      );
      // Every line is an Insert with a green gutter; at instant progress 1 they
      // are fully visible.
      expect(painter.lines, hasLength(2));
      for (final line in painter.lines) {
        expect(line.gutter, const CodeTheme.dark().addedGutter);
        expect(line.opacity, 1.0);
      }
    });
  });

  group('Code.diff reveal and style', () {
    testWidgets('a typing reveal animates the diff progress', (tester) async {
      // typing(10 frames) is the diff window; frame 4 -> progress 0.4.
      final painter = await _diffAt(
        tester,
        const Code.diff(
          _before,
          _after,
          language: 'dart',
          reveal: CodeReveal.typing(Time.frames(10)),
        ),
        frame: 4,
      );
      expect(painter.progress, greaterThan(0.0));
      expect(painter.progress, lessThan(1.0));
    });

    testWidgets('an explicit style sets the painter font family and size', (tester) async {
      final painter = await _diffAt(
        tester,
        const Code.diff(
          _before,
          _after,
          language: 'dart',
          style: TextStyle(fontFamily: 'Courier', fontSize: 18),
        ),
      );
      expect(painter.fontFamily, 'Courier');
      expect(painter.fontSize, 18);
    });

    testWidgets('with no style it defaults to the bundled mono font and size', (tester) async {
      final painter = await _diffAt(tester, const Code.diff(_before, _after, language: 'dart'));
      expect(painter.fontFamily, Code.defaultFontFamily);
      expect(painter.fontSize, 14);
    });
  });

  group('Code.diff structure', () {
    testWidgets('content params only with sensible defaults', (tester) async {
      const code = Code.diff(_before, _after);
      expect(code.source, _before);
      expect(code.language, 'plaintext');
      expect(code.reveal, CodeReveal.instant);
    });

    testWidgets('shared wraps the result in a SharedElement', (tester) async {
      final anchor = Anchor('diff');
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
                  child: Code.diff(_before, _after, language: 'dart', shared: anchor),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(SharedElement), findsOneWidget);
    });

    testWidgets('without shared it mounts no SharedElement', (tester) async {
      await _diffAt(tester, const Code.diff(_before, _after, language: 'dart'));
      expect(find.byType(SharedElement), findsNothing);
    });
  });

  group('DiffPainter shouldRepaint', () {
    testWidgets('repaints when the progress differs', (tester) async {
      final early = await _diffAt(
        tester,
        const Code.diff(
          _before,
          _after,
          language: 'dart',
          reveal: CodeReveal.lineByLine(Time.frames(4)),
        ),
        frame: 1,
      );
      final later = await _diffAt(
        tester,
        const Code.diff(
          _before,
          _after,
          language: 'dart',
          reveal: CodeReveal.lineByLine(Time.frames(4)),
        ),
        frame: 6,
      );
      expect(later.shouldRepaint(early), isTrue);
    });

    testWidgets('does not repaint when nothing changed', (tester) async {
      final a = await _diffAt(tester, const Code.diff(_before, _after, language: 'dart'));
      final b = await _diffAt(tester, const Code.diff(_before, _after, language: 'dart'));
      expect(b.shouldRepaint(a), isFalse);
    });

    testWidgets('repaints when only the highlight tokens differ', (tester) async {
      // Same diff text (so lines and progress match), re-highlighted in a
      // different language: only tokensPerLine changes, and paint reads it.
      final dart = await _diffAt(tester, const Code.diff(_before, _after, language: 'dart'));
      final plain = await _diffAt(
        tester,
        const Code.diff(_before, _after, language: 'plaintext'),
      );
      expect(plain.shouldRepaint(dart), isTrue);
    });
  });
}

/// Mounts the standard diff mid-animation (line-by-line over 10 frames, probed
/// at frame 5 -> progress ~0.5).
Future<DiffPainter> _diffAtMid(WidgetTester tester) => _diffAt(
  tester,
  const Code.diff(
    _before,
    _after,
    language: 'dart',
    reveal: CodeReveal.lineByLine(Time.frames(10)),
  ),
  frame: 5,
);
