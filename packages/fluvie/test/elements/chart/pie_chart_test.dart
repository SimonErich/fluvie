// Epic 10.3 WI-9 (D7/D10): the frame-driven `Chart.pie` and `Chart.donut`. Each
// segment sweeps clockwise from 12 o'clock by `fullAngle x ease(progress)`, so
// at progress 0 nothing is swept and at progress 1 the segments sum to 2 pi with
// each segment proportional to its value. `Chart.donut` cuts an inner radius via
// an even-odd path (no saveLayer). Segment colors cycle the palette. The painter
// exposes its resolved sweep angles and paths so the geometry is asserted
// without a pixel readback.

import 'dart:math' as math;

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/transition/shared_element.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/chart/chart.dart';
import 'package:fluvie/src/elements/chart/pie_chart.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/timing/scene_scope.dart';
import 'package:fluvie/src/timing/video_scope.dart';

/// The size every probe mounts the chart at, so the geometry is known.
const _probeSize = Size(200, 200);

/// Mounts [chart] at [frame] under a 30fps video/scene scope and returns the
/// resolved [PieChartPainter] so its segment geometry can be probed.
Future<PieChartPainter> _piePainterAt(
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
  return paint.painter! as PieChartPainter;
}

void main() {
  group('Chart.pie sweep (frame-driven)', () {
    testWidgets('nothing is swept at frame 0', (tester) async {
      final painter = await _piePainterAt(
        tester,
        Chart.pie(data: const {'A': 1, 'B': 3}, reveal: const Time.frames(30)),
        frame: 0,
      );
      for (final angle in painter.sweepAngles) {
        expect(angle, closeTo(0, 0.0001));
      }
    });

    testWidgets('segments sum to 2 pi at the reveal end', (tester) async {
      final painter = await _piePainterAt(
        tester,
        Chart.pie(data: const {'A': 1, 'B': 3}, reveal: const Time.frames(30)),
        frame: 30,
      );
      final total = painter.sweepAngles.fold<double>(0, (a, b) => a + b);
      expect(total, closeTo(2 * math.pi, 0.0001));
    });

    testWidgets('each full segment angle is proportional to its value', (tester) async {
      final painter = await _piePainterAt(
        tester,
        Chart.pie(data: const {'A': 1, 'B': 3}, reveal: const Time.frames(30)),
        frame: 30,
      );
      // A is 1/4 of the total, B is 3/4.
      expect(painter.sweepAngles[0], closeTo(2 * math.pi * 0.25, 0.0001));
      expect(painter.sweepAngles[1], closeTo(2 * math.pi * 0.75, 0.0001));
    });

    testWidgets('mid-reveal sweeps part of the full angle', (tester) async {
      final painter = await _piePainterAt(
        tester,
        Chart.pie(data: const {'A': 1, 'B': 3}, reveal: const Time.frames(30)),
        frame: 15,
      );
      final total = painter.sweepAngles.fold<double>(0, (a, b) => a + b);
      expect(total, greaterThan(0));
      expect(total, lessThan(2 * math.pi));
    });

    testWidgets("segments start at 12 o'clock", (tester) async {
      final painter = await _piePainterAt(
        tester,
        Chart.pie(data: const {'A': 1, 'B': 1}, reveal: const Time.frames(30)),
        frame: 30,
      );
      // The canvas zero angle is 3 o'clock; 12 o'clock is -pi/2.
      expect(painter.startAngle, closeTo(-math.pi / 2, 0.0001));
    });
  });

  group('Chart.donut hole', () {
    testWidgets('a pie has no inner radius', (tester) async {
      final painter = await _piePainterAt(
        tester,
        Chart.pie(data: const {'A': 1, 'B': 1}, reveal: const Time.frames(30)),
        frame: 30,
      );
      expect(painter.innerRadius, 0);
    });

    testWidgets('a donut leaves a hole (positive inner radius)', (tester) async {
      final painter = await _piePainterAt(
        tester,
        Chart.donut(
          data: const {'A': 1, 'B': 1},
          reveal: const Time.frames(30),
          innerRadius: 0.5,
        ),
        frame: 30,
      );
      expect(painter.innerRadius, 0.5);
      final hole = painter.holeRadius(_probeSize);
      expect(hole, greaterThan(0));
      expect(hole, lessThan(painter.outerRadius(_probeSize)));
    });

    testWidgets('the donut segment path uses an even-odd fill', (tester) async {
      final painter = await _piePainterAt(
        tester,
        Chart.donut(
          data: const {'A': 1, 'B': 1},
          reveal: const Time.frames(30),
          innerRadius: 0.5,
        ),
        frame: 30,
      );
      // The donut hole point (center) is outside the segment ring path.
      final path = painter.segmentPath(_probeSize, 0);
      expect(path.contains(Offset(_probeSize.width / 2, _probeSize.height / 2)), isFalse);
    });
  });

  group('Chart.pie colors', () {
    testWidgets('segment colors cycle the palette', (tester) async {
      final painter = await _piePainterAt(
        tester,
        Chart.pie(data: const {'A': 1, 'B': 2, 'C': 3}, reveal: const Time.frames(30)),
        frame: 30,
      );
      expect(painter.colors.length, 3);
      expect(painter.colors.toSet().length, 3);
    });
  });

  group('Chart.pie content fields and anchor', () {
    test('default reveal is a 0.6 relative window', () {
      final chart = Chart.pie(data: const {'A': 1});
      expect(chart.reveal, const Time.relative(0.6));
    });

    testWidgets('a shared anchor wraps the chart in a SharedElement', (tester) async {
      await _piePainterAt(
        tester,
        Chart.pie(data: const {'A': 1}, shared: Anchor('pie')),
        frame: 30,
      );
      expect(find.byType(SharedElement), findsOneWidget);
    });
  });

  group('Chart.pie determinism', () {
    testWidgets('the same frame resolves identical sweep angles twice', (tester) async {
      final first = await _piePainterAt(
        tester,
        Chart.pie(data: const {'A': 1, 'B': 3, 'C': 2}, reveal: const Time.frames(30)),
        frame: 13,
      );
      final firstAngles = List<double>.of(first.sweepAngles);
      final second = await _piePainterAt(
        tester,
        Chart.pie(data: const {'A': 1, 'B': 3, 'C': 2}, reveal: const Time.frames(30)),
        frame: 13,
      );
      expect(second.sweepAngles, firstAngles);
    });
  });
}
