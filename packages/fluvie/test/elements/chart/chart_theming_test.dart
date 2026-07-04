// Epic 10.4 WI-14 (D12): every chart resolves its colors through
// `context.fluvie.palette`. A chart under a FluvieTokensScope with a custom
// palette paints the custom colors; with no scope it uses the fallback palette;
// a per-series `color:` override wins over the palette slot.

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/chart/bar_chart.dart';
import 'package:fluvie/src/elements/chart/chart.dart';
import 'package:fluvie/src/elements/chart/data/chart_series.dart';
import 'package:fluvie/src/elements/chart/line_chart.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/theme/fluvie_tokens.dart';
import 'package:fluvie/src/theme/fluvie_tokens_scope.dart';
import 'package:fluvie/src/timing/scene_scope.dart';
import 'package:fluvie/src/timing/video_scope.dart';

const _custom = FluvieTokens(
  palette: ChartPalette([Color(0xFFAA0000), Color(0xFF00BB00)]),
  axisColor: Color(0xFF111111),
  gridColor: Color(0xFF222222),
  labelColor: Color(0xFF333333),
);

/// Mounts [chart] at the reveal-end [frame] under a 30fps scope, optionally
/// inside a [FluvieTokensScope] carrying [tokens], and returns the resolved
/// painter for probing.
Future<T> _painterAt<T extends CustomPainter>(
  WidgetTester tester,
  Chart chart, {
  int frame = 30,
  FluvieTokens? tokens,
}) async {
  Widget child = SizedBox(width: 200, height: 200, child: chart);
  if (tokens != null) child = FluvieTokensScope(tokens: tokens, child: child);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RenderControllerScope(
        controller: RenderController(initialFrame: frame),
        child: VideoScope(
          fps: 30,
          duration: const Time.frames(120),
          child: SceneScope(duration: const Time.frames(120), child: child),
        ),
      ),
    ),
  );
  final paint = tester.widget<CustomPaint>(
    find.descendant(of: find.byType(Chart), matching: find.byType(CustomPaint)).first,
  );
  return paint.painter! as T;
}

void main() {
  group('Chart theming via context.fluvie (WI-14)', () {
    testWidgets('a bar chart under a custom-palette scope paints the custom colors', (
      tester,
    ) async {
      final painter = await _painterAt<BarChartPainter>(
        tester,
        Chart.bar(data: const {'A': 30, 'B': 80}, reveal: const Time.frames(30)),
        tokens: _custom,
      );
      expect(painter.colors[0], const Color(0xFFAA0000));
      expect(painter.colors[1], const Color(0xFF00BB00));
    });

    testWidgets('a bar chart with no scope uses the fallback palette', (tester) async {
      final painter = await _painterAt<BarChartPainter>(
        tester,
        Chart.bar(data: const {'A': 30, 'B': 80}, reveal: const Time.frames(30)),
      );
      const fallback = FluvieTokens.fallback();
      expect(painter.colors[0], fallback.palette.colorAt(0));
      expect(painter.colors[1], fallback.palette.colorAt(1));
    });

    testWidgets('a line series color override wins over the scope palette', (tester) async {
      final painter = await _painterAt<LineChartPainter>(
        tester,
        Chart.line.series(
          const [
            ChartSeries.values(
              name: 'Sales',
              data: {'A': 1, 'B': 2, 'C': 3},
              color: Color(0xFF123456),
            ),
          ],
          reveal: const Time.frames(30),
        ),
        tokens: _custom,
      );
      expect(painter.colors.first, const Color(0xFF123456));
    });
  });
}
