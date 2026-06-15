// Epic 10.3 WI-10 (D6/D7): the frame-driven `Chart.scatter`. Each point's scale
// springs 0 -> 1 with an overshoot mid-pop (the Ease.elastic vocabulary). A
// `Stagger` offsets each point's pop, so point i is still 0 while point i-1
// pops. Points place at (LinearScale x, LinearScale y). The painter exposes its
// resolved per-point scales and centers so the pop and placement are asserted
// without a pixel readback.

import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/transition/shared_element.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/chart/chart.dart';
import 'package:fluvie/src/elements/chart/data/chart_point.dart';
import 'package:fluvie/src/elements/chart/data/chart_series.dart';
import 'package:fluvie/src/elements/chart/scatter_chart.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/timing/scene_scope.dart';
import 'package:fluvie/src/timing/video_scope.dart';

/// The size every probe mounts the chart at, so the placement is known.
const _probeSize = Size(200, 200);

/// Mounts [chart] at [frame] under a 30fps video/scene scope and returns the
/// resolved [ScatterChartPainter] so its point geometry can be probed.
Future<ScatterChartPainter> _scatterPainterAt(
  WidgetTester tester,
  Chart chart, {
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
          child: SceneScope(
            duration: Time.frames(sceneFrames),
            child: SizedBox(
              width: _probeSize.width,
              height: _probeSize.height,
              child: chart,
            ),
          ),
        ),
      ),
    ),
  );
  final paint = tester.widget<CustomPaint>(
    find.descendant(of: find.byType(Chart), matching: find.byType(CustomPaint)).first,
  );
  return paint.painter! as ScatterChartPainter;
}

const _points = [
  ChartPoint(x: 1, y: 2),
  ChartPoint(x: 3, y: 5),
  ChartPoint(x: 5, y: 1),
];

void main() {
  group('Chart.scatter pop (frame-driven)', () {
    testWidgets('every point scale is zero at frame 0', (tester) async {
      final painter = await _scatterPainterAt(
        tester,
        Chart.scatter(points: _points, popIn: const Time.frames(30)),
        frame: 0,
      );
      for (final scale in painter.scales) {
        expect(scale, closeTo(0, 0.0001));
      }
    });

    testWidgets('every point scale settles to one at the reveal end', (tester) async {
      final painter = await _scatterPainterAt(
        tester,
        Chart.scatter(points: _points, popIn: const Time.frames(30)),
        frame: 30,
      );
      for (final scale in painter.scales) {
        expect(scale, closeTo(1, 0.0001));
      }
    });

    testWidgets('the spring overshoots past one mid-pop', (tester) async {
      // Sweep the reveal window; an elastic / spring pop crosses above 1.0.
      var sawOvershoot = false;
      for (var frame = 1; frame < 30; frame++) {
        final painter = await _scatterPainterAt(
          tester,
          Chart.scatter(points: _points, popIn: const Time.frames(30)),
          frame: frame,
        );
        if (painter.scales.first > 1.0001) sawOvershoot = true;
      }
      expect(sawOvershoot, isTrue);
    });
  });

  group('Chart.scatter stagger', () {
    testWidgets('point i is still 0 while point i-1 pops', (tester) async {
      // gap 10 frames: at frame 4, point 0 (offset 0) pops, points 1 and 2
      // (offsets 10, 20) have not started.
      final painter = await _scatterPainterAt(
        tester,
        Chart.scatter(
          points: _points,
          popIn: const Time.frames(20),
          stagger: const Stagger.each(Time.frames(10)),
        ),
        frame: 4,
      );
      expect(painter.scales[0], greaterThan(0));
      expect(painter.scales[1], closeTo(0, 0.0001));
      expect(painter.scales[2], closeTo(0, 0.0001));
    });

    testWidgets('a later frame pops the delayed point', (tester) async {
      final painter = await _scatterPainterAt(
        tester,
        Chart.scatter(
          points: _points,
          popIn: const Time.frames(20),
          stagger: const Stagger.each(Time.frames(10)),
        ),
        frame: 14,
      );
      expect(painter.scales[1], greaterThan(0));
    });
  });

  group('Chart.scatter placement', () {
    testWidgets('points place at (LinearScale x, LinearScale y)', (tester) async {
      final painter = await _scatterPainterAt(
        tester,
        Chart.scatter(points: _points, popIn: const Time.frames(30)),
        frame: 30,
      );
      final centers = painter.centersFor(_probeSize);
      // The smallest x maps to the smallest pixel-x; the largest to the largest.
      expect(centers[0].dx, lessThan(centers[1].dx));
      expect(centers[1].dx, lessThan(centers[2].dx));
      // A larger y sits higher on screen (smaller pixel-y).
      expect(centers[1].dy, lessThan(centers[0].dy));
      expect(centers[0].dy, lessThan(centers[2].dy));
    });

    testWidgets('a category map places points at the category index x', (tester) async {
      final painter = await _scatterPainterAt(
        tester,
        Chart.scatter(data: const {'A': 2, 'B': 5}, popIn: const Time.frames(30)),
        frame: 30,
      );
      final centers = painter.centersFor(_probeSize);
      expect(centers.length, 2);
      expect(centers[0].dx, lessThan(centers[1].dx));
    });
  });

  group('Chart.scatter.series', () {
    testWidgets('resolves the series points and one scale per point', (tester) async {
      final painter = await _scatterPainterAt(
        tester,
        Chart.scatter.series(
          const ChartSeries.points(name: 'cloud', data: _points),
          popIn: const Time.frames(30),
        ),
        frame: 30,
      );
      // The three series points place left to right at full pop.
      final centers = painter.centersFor(_probeSize);
      expect(centers.length, _points.length);
      expect(centers[0].dx, lessThan(centers[1].dx));
      expect(centers[1].dx, lessThan(centers[2].dx));
      expect(painter.scales.length, _points.length);
    });

    testWidgets('a series color override flows to the painter', (tester) async {
      const override = Color(0xFF123456);
      final painter = await _scatterPainterAt(
        tester,
        Chart.scatter.series(
          const ChartSeries.points(name: 'cloud', data: _points, color: override),
          popIn: const Time.frames(30),
        ),
        frame: 30,
      );
      expect(painter.color, override);
    });
  });

  group('Chart.scatter content fields and anchor', () {
    test('default popIn is a 0.6 relative window', () {
      final chart = Chart.scatter(data: const {'A': 1});
      expect(chart.reveal, const Time.relative(0.6));
    });

    testWidgets('a shared anchor wraps the chart in a SharedElement', (tester) async {
      await _scatterPainterAt(
        tester,
        Chart.scatter(data: const {'A': 1}, shared: Anchor('scatter')),
        frame: 30,
      );
      expect(find.byType(SharedElement), findsOneWidget);
    });
  });

  group('Chart.scatter determinism', () {
    testWidgets('the same frame resolves identical scales and centers twice', (tester) async {
      final first = await _scatterPainterAt(
        tester,
        Chart.scatter(points: _points, popIn: const Time.frames(30)),
        frame: 12,
      );
      final firstScales = List<double>.of(first.scales);
      final firstCenters = List<Offset>.of(first.centersFor(_probeSize));
      final second = await _scatterPainterAt(
        tester,
        Chart.scatter(points: _points, popIn: const Time.frames(30)),
        frame: 12,
      );
      expect(second.scales, firstScales);
      expect(second.centersFor(_probeSize), firstCenters);
    });
  });
}
