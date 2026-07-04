// Epic 10.2 WI-6 (D1/D2/D6/D7): the intrinsic, frame-driven `Chart.bar`. Each
// bar grows from the baseline by `height x ease(segmentProgress)`, where the
// segment progress is the frames elapsed over the resolved `reveal`, optionally
// delayed per bar by a `Stagger`. The widget reads the frame clock + scope, the
// reveal is intrinsic (transforms ride `.animate()`), and a `shared:` anchor
// wraps the result in a `SharedElement`. The painter exposes its resolved bar
// rects so the geometry is asserted without a pixel readback.

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/transition/shared_element.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/chart/bar_chart.dart';
import 'package:fluvie/src/elements/chart/chart.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/timing/scene_scope.dart';
import 'package:fluvie/src/timing/video_scope.dart';

/// The size every probe mounts the chart at, so the resolved scales are known.
const _probeSize = Size(200, 200);

/// Mounts [chart] at [frame] under a 30fps video/scene scope sized
/// [_probeSize] and returns the resolved [BarChartPainter] so its bar geometry
/// can be probed.
Future<BarChartPainter> _barPainterAt(
  WidgetTester tester,
  Chart chart, {
  required int frame,
  int sceneFrames = 120,
  Size size = _probeSize,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RenderControllerScope(
        controller: RenderController(initialFrame: frame),
        child: VideoScope(
          fps: 30,
          duration: Time.frames(sceneFrames),
          child: SceneScope(
            duration: Time.frames(sceneFrames),
            child: SizedBox(width: size.width, height: size.height, child: chart),
          ),
        ),
      ),
    ),
  );
  final paint = tester.widget<CustomPaint>(
    find.descendant(of: find.byType(Chart), matching: find.byType(CustomPaint)).first,
  );
  return paint.painter! as BarChartPainter;
}

/// The drawn height of the bar at [index] (baseline minus its top edge).
double _barHeight(BarChartPainter painter, int index) {
  final rect = painter.barRectsFor(_probeSize)[index];
  return painter.valueScale(_probeSize).baselinePixel - rect.top;
}

void main() {
  group('Chart.bar reveal (frame-driven)', () {
    testWidgets('every bar is zero height at frame 0', (tester) async {
      final painter = await _barPainterAt(
        tester,
        Chart.bar(data: const {'A': 30, 'B': 80}, reveal: const Time.frames(30)),
        frame: 0,
      );
      expect(_barHeight(painter, 0), 0);
      expect(_barHeight(painter, 1), 0);
    });

    testWidgets('every bar is at full scaled height at the reveal end', (tester) async {
      final painter = await _barPainterAt(
        tester,
        Chart.bar(data: const {'A': 30, 'B': 80}, reveal: const Time.frames(30)),
        frame: 30,
      );
      final value = painter.valueScale(_probeSize);
      final fullA = value.baselinePixel - value.toPixel(30);
      final fullB = value.baselinePixel - value.toPixel(80);
      expect(_barHeight(painter, 0), closeTo(fullA, 0.001));
      expect(_barHeight(painter, 1), closeTo(fullB, 0.001));
    });

    testWidgets('mid-reveal is between zero and full', (tester) async {
      final painter = await _barPainterAt(
        tester,
        Chart.bar(data: const {'A': 30, 'B': 80}, reveal: const Time.frames(30)),
        frame: 15,
      );
      final value = painter.valueScale(_probeSize);
      final fullB = value.baselinePixel - value.toPixel(80);
      final mid = _barHeight(painter, 1);
      expect(mid, greaterThan(0));
      expect(mid, lessThan(fullB));
    });
  });

  group('Chart.bar stagger', () {
    testWidgets('delays bar i by i x gap (bar B still 0 while A grows)', (tester) async {
      // gap 6 frames: at frame 4, bar A (offset 0) has grown, bar B (offset 6)
      // has not started.
      final painter = await _barPainterAt(
        tester,
        Chart.bar(
          data: const {'A': 30, 'B': 80},
          reveal: const Time.frames(30),
          stagger: const Stagger.each(Time.frames(6)),
        ),
        frame: 4,
      );
      expect(_barHeight(painter, 0), greaterThan(0));
      expect(_barHeight(painter, 1), 0);
    });

    testWidgets('a later frame grows the delayed bar', (tester) async {
      final painter = await _barPainterAt(
        tester,
        Chart.bar(
          data: const {'A': 30, 'B': 80},
          reveal: const Time.frames(30),
          stagger: const Stagger.each(Time.frames(6)),
        ),
        frame: 12,
      );
      expect(_barHeight(painter, 1), greaterThan(0));
    });
  });

  group('Chart.bar content fields', () {
    test('exposes data, reveal, and stagger (content params only)', () {
      final chart = Chart.bar(
        data: const {'A': 1, 'B': 2},
        reveal: const Time.frames(20),
        stagger: const Stagger.each(Time.frames(3)),
      );
      expect(chart.data, const {'A': 1, 'B': 2});
      expect(chart.reveal, const Time.frames(20));
      expect(chart.stagger, const Stagger.each(Time.frames(3)));
    });

    test('default reveal is a 0.6 relative window', () {
      final chart = Chart.bar(data: const {'A': 1});
      expect(chart.reveal, const Time.relative(0.6));
      expect(chart.stagger, isNull);
    });
  });

  group('Chart.bar shared anchor', () {
    testWidgets('null shared mounts no SharedElement', (tester) async {
      await _barPainterAt(tester, Chart.bar(data: const {'A': 1}), frame: 30);
      expect(find.byType(SharedElement), findsNothing);
    });

    testWidgets('a shared anchor wraps the chart in a SharedElement', (tester) async {
      final anchor = Anchor('chart');
      await _barPainterAt(
        tester,
        Chart.bar(data: const {'A': 1}, shared: anchor),
        frame: 30,
      );
      expect(find.byType(SharedElement), findsOneWidget);
    });
  });

  group('Chart.bar determinism', () {
    testWidgets('the same frame resolves identical bar rects twice', (tester) async {
      final first = await _barPainterAt(
        tester,
        Chart.bar(data: const {'A': 30, 'B': 80, 'C': 55}, reveal: const Time.frames(30)),
        frame: 17,
      );
      final firstRects = List<Rect>.of(first.barRectsFor(_probeSize));
      final second = await _barPainterAt(
        tester,
        Chart.bar(data: const {'A': 30, 'B': 80, 'C': 55}, reveal: const Time.frames(30)),
        frame: 17,
      );
      expect(second.barRectsFor(_probeSize), firstRects);
    });
  });
}
