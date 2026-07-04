// WI-18 (D10/D14, §15): the intrinsic, frame-driven `Counter`. The value is
// `lerp(from, to, ease(progress))` where progress is the frames elapsed over the
// resolved duration, formatted by an `intl` NumberFormat at a fixed locale (no
// DateTime, no ambient locale), so the output is byte-identical everywhere. The
// `.currency`/`.percent` factories pin their formats; `NumberFormat.compact()`
// renders "12.5K".

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/counter.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/timing/scene_scope.dart';
import 'package:fluvie/src/timing/video_scope.dart';
import 'package:intl/intl.dart' show NumberFormat;

/// Mounts [child] at [frame] under a 30fps video/scene scope and returns the
/// formatted number string the counter painted.
Future<String> _countAt(
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
  group('Counter value tween (frame-driven)', () {
    testWidgets('reads the from value at frame 0', (tester) async {
      // duration 1s = 30 frames, linear ease, 0 -> 100.
      final at0 = await _countAt(
        tester,
        const Counter(to: 100),
        frame: 0,
      );
      expect(at0, '0');
    });

    testWidgets('lerps linearly to the midpoint', (tester) async {
      // duration 30 frames, linear; frame 15 -> progress 0.5 -> 50.
      final mid = await _countAt(
        tester,
        const Counter(to: 100),
        frame: 15,
      );
      expect(mid, '50');
    });

    testWidgets('clamps to the to value at and past the end', (tester) async {
      final end = await _countAt(
        tester,
        const Counter(to: 100),
        frame: 30,
      );
      final past = await _countAt(
        tester,
        const Counter(to: 100),
        frame: 90,
      );
      expect(end, '100');
      expect(past, '100');
    });

    testWidgets('honors a non-zero from', (tester) async {
      final mid = await _countAt(
        tester,
        const Counter(to: 100, from: 50),
        frame: 15,
      );
      expect(mid, '75');
    });

    testWidgets('applies the ease curve to progress', (tester) async {
      // easeOut (snappy) is past 0.5 at the temporal midpoint, so the value is
      // above the linear 50 at frame 15.
      final linear = await _countAt(
        tester,
        const Counter(to: 100),
        frame: 15,
      );
      final eased = await _countAt(
        tester,
        const Counter(to: 100, ease: Ease.snappy),
        frame: 15,
      );
      expect(double.parse(linear), 50);
      expect(double.parse(eased.replaceAll(',', '')), greaterThan(50));
    });

    testWidgets('counts elapsed from the scene scope start', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RenderControllerScope(
            controller: RenderController(initialFrame: 45),
            child: const VideoScope(
              fps: 30,
              duration: Time.frames(120),
              child: SceneScope(
                start: Time.frames(30),
                duration: Time.frames(90),
                child: Counter(to: 100),
              ),
            ),
          ),
        ),
      );
      // Elapsed 15 of 30 frames -> 50.
      expect(tester.widget<Text>(find.byType(Text)).data, '50');
    });
  });

  group('Counter formatting', () {
    testWidgets('compact format renders 12.5K at the end', (tester) async {
      final value = await _countAt(
        tester,
        Counter(to: 12500, format: NumberFormat.compact()),
        frame: 60,
      );
      expect(value, '12.5K');
    });

    testWidgets('currency prefixes the symbol at a fixed locale', (tester) async {
      final value = await _countAt(
        tester,
        Counter.currency(to: 4999),
        frame: 60,
      );
      expect(value, r'$4,999');
    });

    testWidgets('currency takes a custom symbol', (tester) async {
      final value = await _countAt(
        tester,
        Counter.currency(to: 100, symbol: '€'),
        frame: 60,
      );
      expect(value.startsWith('€'), isTrue);
      expect(value.contains('100'), isTrue);
    });

    testWidgets('percent renders a percentage at the end', (tester) async {
      final value = await _countAt(
        tester,
        Counter.percent(to: 0.87),
        frame: 60,
      );
      expect(value, '87%');
    });

    testWidgets('default format groups thousands at a fixed locale', (tester) async {
      final value = await _countAt(
        tester,
        const Counter(to: 48230),
        frame: 60,
      );
      expect(value, '48,230');
    });
  });

  group('Counter clock requirements', () {
    testWidgets('throws a FluvieTimingError without a frame clock', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: VideoScope(
            fps: 30,
            duration: Time.frames(120),
            child: SceneScope(duration: Time.frames(120), child: Counter(to: 10)),
          ),
        ),
      );
      expect(tester.takeException(), isA<FluvieTimingError>());
    });
  });

  group('Counter carries its content fields', () {
    test('exposes to, from, duration, and style', () {
      const style = TextStyle(fontSize: 40);
      const counter = Counter(
        to: 200,
        from: 10,
        reveal: Time.seconds(2),
        style: style,
      );
      expect(counter.to, 200);
      expect(counter.from, 10);
      expect(counter.reveal, const Time.seconds(2));
      expect(counter.style, same(style));
    });

    test('defaults: from 0, reveal 1s, no format, no style', () {
      const counter = Counter(to: 5);
      expect(counter.from, 0);
      expect(counter.reveal, const Time.seconds(1));
      expect(counter.format, isNull);
      expect(counter.style, isNull);
    });
  });

  group('Counter determinism', () {
    testWidgets('the same frame renders the same string twice', (tester) async {
      final first = await _countAt(
        tester,
        const Counter(to: 99999),
        frame: 12,
      );
      final second = await _countAt(
        tester,
        const Counter(to: 99999),
        frame: 12,
      );
      expect(first, second);
    });
  });
}
