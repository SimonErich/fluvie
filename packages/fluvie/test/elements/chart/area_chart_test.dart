// Epic 10.2 WI-7 (D7): the frame-driven `Chart.area`. The fill follows the line
// sweep and closes to the baseline, clipped to the swept x-extent (it fills
// *under* the advancing line). The multi-series `Chart.area.series([...])`
// stacks one filled area per series.

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/chart/area_chart.dart';
import 'package:fluvie/src/elements/chart/chart.dart';
import 'package:fluvie/src/elements/chart/data/chart_series.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/timing/scene_scope.dart';
import 'package:fluvie/src/timing/video_scope.dart';

const _probeSize = Size(200, 200);

/// Mounts [chart] at [frame] and returns the resolved [AreaChartPainter].
Future<AreaChartPainter> _areaPainterAt(
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
  return paint.painter! as AreaChartPainter;
}

void main() {
  group('Chart.area sweep (frame-driven)', () {
    testWidgets('the filled area is empty at frame 0', (tester) async {
      final painter = await _areaPainterAt(
        tester,
        Chart.area(data: const {'A': 10, 'B': 40, 'C': 25}, reveal: const Time.frames(30)),
        frame: 0,
      );
      expect(painter.fillArea(_probeSize, 0), closeTo(0, 0.001));
    });

    testWidgets('the filled area grows with the sweep', (tester) async {
      final mid = await _areaPainterAt(
        tester,
        Chart.area(data: const {'A': 10, 'B': 40, 'C': 25}, reveal: const Time.frames(30)),
        frame: 15,
      );
      final midArea = mid.fillArea(_probeSize, 0);
      final full = await _areaPainterAt(
        tester,
        Chart.area(data: const {'A': 10, 'B': 40, 'C': 25}, reveal: const Time.frames(30)),
        frame: 30,
      );
      expect(midArea, greaterThan(0));
      expect(midArea, lessThan(full.fillArea(_probeSize, 0)));
    });

    testWidgets('the fill closes to the baseline (bottom edge present)', (tester) async {
      final painter = await _areaPainterAt(
        tester,
        Chart.area(data: const {'A': 10, 'B': 40, 'C': 25}, reveal: const Time.frames(30)),
        frame: 30,
      );
      final bounds = painter.fillPath(_probeSize, 0).getBounds();
      expect(bounds.bottom, closeTo(painter.valueScale(_probeSize).baselinePixel, 0.001));
    });
  });

  group('Chart.area series count', () {
    testWidgets('multi-series fills n areas', (tester) async {
      final painter = await _areaPainterAt(
        tester,
        Chart.area.series(
          const [
            ChartSeries.values(name: 'one', data: {'A': 1, 'B': 4}),
            ChartSeries.values(name: 'two', data: {'A': 3, 'B': 2}),
          ],
          reveal: const Time.frames(30),
        ),
        frame: 30,
      );
      expect(painter.seriesCount, 2);
    });
  });

  group('Chart.area determinism', () {
    testWidgets('the same frame resolves the same fill area twice', (tester) async {
      final first = await _areaPainterAt(
        tester,
        Chart.area(data: const {'A': 10, 'B': 40, 'C': 25}, reveal: const Time.frames(30)),
        frame: 13,
      );
      final firstArea = first.fillArea(_probeSize, 0);
      final second = await _areaPainterAt(
        tester,
        Chart.area(data: const {'A': 10, 'B': 40, 'C': 25}, reveal: const Time.frames(30)),
        frame: 13,
      );
      expect(second.fillArea(_probeSize, 0), firstArea);
    });
  });
}
