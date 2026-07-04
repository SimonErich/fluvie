// Epic 10.4 WI-15 (10.4 ACCEPTANCE): a themed, animated chart end to end. A
// `Chart.bar(...).animate([Animation.slideFade()])` inside a Scene with a
// Background and a FluvieTokensScope, under the real Video/render scopes,
// resolves to a warning-free timeline and renders deterministically at a mid
// frame — the .animate() outer transform composes with the intrinsic reveal.

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/composition/background/background.dart';
import 'package:fluvie/src/composition/runtime/timeline_probe.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/elements/chart/bar_chart.dart';
import 'package:fluvie/src/elements/chart/chart.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';
import 'package:fluvie/src/theme/fluvie_tokens.dart';
import 'package:fluvie/src/theme/fluvie_tokens_scope.dart';
import 'package:fluvie/src/timing/timeline/debug_timeline.dart';

const _brand = FluvieTokens(
  palette: ChartPalette([Color(0xFFAA0000), Color(0xFF00BB00)]),
  axisColor: Color(0xFF9E9E9E),
  gridColor: Color(0x33FFFFFF),
  labelColor: Color(0xFFE0E0E0),
);

Video _themedChartVideo() => Video(
  scenes: [
    Scene(
      duration: 60.frames,
      background: Background.color(const Color(0xFF101820)),
      children: [
        FluvieTokensScope(
          tokens: _brand,
          child: SizedBox(
            width: 200,
            height: 200,
            child: Chart.bar(
              data: const {'A': 30, 'B': 80},
              growIn: const Time.frames(30),
            ).animate([Animation.slideFade()]),
          ),
        ),
      ],
    ),
  ],
);

void main() {
  group('Chart themed + animated integration (WI-15)', () {
    testWidgets('resolves to a warning-free timeline under the real scopes', (tester) async {
      final probe = TimelineProbe();
      final controller = RenderController();
      await tester.pumpWidget(
        RenderModeContext(
          mode: RenderMode.preview,
          child: RenderControllerScope(
            controller: controller,
            child: TimelineProbeScope(
              probe: probe,
              child: Directionality(textDirection: TextDirection.ltr, child: _themedChartVideo()),
            ),
          ),
        ),
      );
      await tester.pump();

      final timeline = probe.value;
      expect(timeline, isNotNull);
      expect(
        timeline!.warnings,
        isEmpty,
        reason: 'themed chart resolved with warnings:\n${debugTimeline(timeline)}',
      );
      expect(timeline.rows, isNotEmpty);
    });

    testWidgets('renders deterministically at a mid frame (the reveal + outer transform)', (
      tester,
    ) async {
      Future<BarChartPainter> paintAt(int frame) async {
        final controller = RenderController(initialFrame: frame);
        await tester.pumpWidget(
          RenderModeContext(
            mode: RenderMode.capture,
            child: RenderControllerScope(
              controller: controller,
              child: Directionality(textDirection: TextDirection.ltr, child: _themedChartVideo()),
            ),
          ),
        );
        await tester.pump();
        final paint = tester.widget<CustomPaint>(
          find.descendant(of: find.byType(Chart), matching: find.byType(CustomPaint)).first,
        );
        return paint.painter! as BarChartPainter;
      }

      const size = Size(200, 200);
      final first = await paintAt(15);
      final firstRects = List<Rect>.of(first.barRectsFor(size));
      // The custom palette themes the bars: the .animate transform never touches
      // the painter's resolved colors.
      expect(first.colors.first, const Color(0xFFAA0000));

      final second = await paintAt(15);
      expect(second.barRectsFor(size), firstRects);
      expect(second.colors, first.colors);
    });
  });
}
