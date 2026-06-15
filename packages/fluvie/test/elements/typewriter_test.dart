// WI-17 (D10, §15): the intrinsic, frame-driven `Typewriter`. The visible glyph
// count is `floor(elapsed / speed)` clamped to `[0, text.length]`, read from the
// FrameProvider (the only clock); the optional caret blinks on a frame-pinned
// period; content params only (transforms go through `.animate()`); no scope is
// a hard error.

import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/typewriter.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/timing/scene_scope.dart';
import 'package:fluvie/src/timing/video_scope.dart';

/// Mounts [child] at [frame] under a video/scene scope so the frame is the only
/// clock, then returns the visible `Text` string the typewriter painted.
Future<String> _typedAt(
  WidgetTester tester,
  Widget child, {
  required int frame,
  int sceneFrames = 120,
}) async {
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
  final text = tester.widget<Text>(find.byType(Text));
  return text.data ?? '';
}

void main() {
  const sample = 'Hello';

  group('Typewriter glyph reveal (frame-driven)', () {
    testWidgets('shows no glyphs at frame 0', (tester) async {
      expect(await _typedAt(tester, const Typewriter(sample), frame: 0), '');
    });

    testWidgets('reveals floor(elapsed / speed) glyphs mid-window', (tester) async {
      // speed = 2 frames/glyph; at frame 6, floor(6 / 2) = 3 glyphs.
      expect(await _typedAt(tester, const Typewriter(sample), frame: 6), 'Hel');
    });

    testWidgets('floors a partial glyph down', (tester) async {
      // speed = 3 frames/glyph; at frame 7, floor(7 / 3) = 2 glyphs.
      expect(
        await _typedAt(
          tester,
          const Typewriter(sample, speed: Time.frames(3)),
          frame: 7,
        ),
        'He',
      );
    });

    testWidgets('clamps to the full text once every glyph is revealed', (tester) async {
      // speed = 2 frames/glyph; at frame 100, floor would be 50, clamped to 5.
      expect(await _typedAt(tester, const Typewriter(sample), frame: 100), sample);
    });

    testWidgets('an empty text stays empty at every frame', (tester) async {
      expect(await _typedAt(tester, const Typewriter(''), frame: 40), '');
    });

    testWidgets('counts elapsed from the scene scope start, not absolute zero', (tester) async {
      // A nested SceneScope starting at frame 30: at absolute frame 36 the
      // elapsed is 6, so floor(6 / 2) = 3 glyphs even though the absolute
      // frame is well past the start.
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RenderControllerScope(
            controller: RenderController(initialFrame: 36),
            child: const VideoScope(
              fps: 30,
              duration: Time.frames(120),
              child: SceneScope(
                start: Time.frames(30),
                duration: Time.frames(90),
                child: Typewriter(sample),
              ),
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.data, 'Hel');
    });
  });

  group('Typewriter caret', () {
    testWidgets('caret: false never appends a caret', (tester) async {
      expect(await _typedAt(tester, const Typewriter(sample), frame: 100), sample);
    });

    testWidgets('caret: true blinks on a frame-pinned period', (tester) async {
      // The caret is on for the first half of each blink period and off for the
      // second. The period is golden-pinned at 16 frames, so frame 0 is on and
      // frame 8 is off.
      final on = await _typedAt(
        tester,
        const Typewriter(sample, caret: true),
        frame: 0,
      );
      final off = await _typedAt(
        tester,
        const Typewriter(sample, caret: true),
        frame: 8,
      );
      expect(on.endsWith('|'), isTrue);
      expect(off.endsWith('|'), isFalse);
    });
  });

  group('Typewriter clock requirements', () {
    testWidgets('throws a FluvieTimingError without a time scope', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RenderControllerScope(
            controller: RenderController(),
            child: const Typewriter(sample),
          ),
        ),
      );
      expect(tester.takeException(), isA<FluvieTimingError>());
    });

    testWidgets('throws a FluvieTimingError without a frame clock', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: VideoScope(
            fps: 30,
            duration: Time.frames(120),
            child: SceneScope(duration: Time.frames(120), child: Typewriter(sample)),
          ),
        ),
      );
      expect(tester.takeException(), isA<FluvieTimingError>());
    });
  });

  group('Typewriter carries its content fields', () {
    test('exposes text, speed, caret, and style', () {
      const style = TextStyle(fontSize: 24);
      const typewriter = Typewriter(
        sample,
        speed: Time.frames(4),
        caret: true,
        style: style,
      );
      expect(typewriter.text, sample);
      expect(typewriter.speed, const Time.frames(4));
      expect(typewriter.caret, isTrue);
      expect(typewriter.style, same(style));
    });

    test('defaults: 2-frame speed, no caret, no style', () {
      const typewriter = Typewriter(sample);
      expect(typewriter.speed, const Time.frames(2));
      expect(typewriter.caret, isFalse);
      expect(typewriter.style, isNull);
    });
  });
}
