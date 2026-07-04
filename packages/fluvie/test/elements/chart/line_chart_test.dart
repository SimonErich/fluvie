// Epic 10.2 WI-7 (D7): the frame-driven `Chart.line`. The polyline is trimmed
// to `progress` of its total length (a left-to-right sweep via PathMetric),
// so at progress 0.5 the painted length is about half the total. The multi-
// series `Chart.line.series([...])` paints one colored polyline per series.

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/chart/chart.dart';
import 'package:fluvie/src/elements/chart/data/chart_series.dart';
import 'package:fluvie/src/elements/chart/line_chart.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/timing/scene_scope.dart';
import 'package:fluvie/src/timing/video_scope.dart';

const _probeSize = Size(200, 200);

/// Mounts [chart] at [frame] and returns the resolved [LineChartPainter].
Future<LineChartPainter> _linePainterAt(
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
  return paint.painter! as LineChartPainter;
}

void main() {
  group('Chart.line sweep (frame-driven)', () {
    testWidgets('paints no length at frame 0', (tester) async {
      final painter = await _linePainterAt(
        tester,
        Chart.line(data: const {'A': 10, 'B': 40, 'C': 25}, reveal: const Time.frames(30)),
        frame: 0,
      );
      expect(painter.sweptLength(_probeSize, 0), closeTo(0, 0.001));
    });

    testWidgets('paints about half the total at progress 0.5', (tester) async {
      final painter = await _linePainterAt(
        tester,
        Chart.line(data: const {'A': 10, 'B': 40, 'C': 25}, reveal: const Time.frames(30)),
        frame: 15,
      );
      final total = painter.totalLength(_probeSize, 0);
      expect(painter.sweptLength(_probeSize, 0), closeTo(total / 2, 0.5));
    });

    testWidgets('paints the full length at the reveal end', (tester) async {
      final painter = await _linePainterAt(
        tester,
        Chart.line(data: const {'A': 10, 'B': 40, 'C': 25}, reveal: const Time.frames(30)),
        frame: 30,
      );
      final total = painter.totalLength(_probeSize, 0);
      expect(painter.sweptLength(_probeSize, 0), closeTo(total, 0.001));
    });
  });

  group('Chart.line series count', () {
    testWidgets('single series draws one polyline', (tester) async {
      final painter = await _linePainterAt(
        tester,
        Chart.line(data: const {'A': 1, 'B': 2}, reveal: const Time.frames(30)),
        frame: 30,
      );
      expect(painter.seriesCount, 1);
    });

    testWidgets('multi-series draws n colored polylines', (tester) async {
      final painter = await _linePainterAt(
        tester,
        Chart.line.series(
          const [
            ChartSeries.values(name: 'one', data: {'A': 1, 'B': 4}),
            ChartSeries.values(name: 'two', data: {'A': 3, 'B': 2}),
            ChartSeries.values(name: 'three', data: {'A': 2, 'B': 5}),
          ],
          reveal: const Time.frames(30),
        ),
        frame: 30,
      );
      expect(painter.seriesCount, 3);
      // Each series carries a distinct resolved color.
      expect(painter.colors.toSet().length, 3);
    });
  });

  group('Chart.line content fields', () {
    test('default reveal is a 0.6 relative window', () {
      final chart = Chart.line(data: const {'A': 1});
      expect(chart.reveal, const Time.relative(0.6));
    });
  });

  group('Chart.line determinism', () {
    testWidgets('the same frame resolves the same swept length twice', (tester) async {
      final first = await _linePainterAt(
        tester,
        Chart.line(data: const {'A': 10, 'B': 40, 'C': 25}, reveal: const Time.frames(30)),
        frame: 11,
      );
      final firstLen = first.sweptLength(_probeSize, 0);
      final second = await _linePainterAt(
        tester,
        Chart.line(data: const {'A': 10, 'B': 40, 'C': 25}, reveal: const Time.frames(30)),
        frame: 11,
      );
      expect(second.sweptLength(_probeSize, 0), firstLen);
    });
  });
}
