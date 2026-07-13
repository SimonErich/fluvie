@Tags(['golden'])
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';
import 'package:fluvie_presenter/src/shell/ui_state.dart';
import 'package:fluvie_presenter/src/sidebar/overview_grid.dart';
import 'package:fluvie_presenter/src/sidebar/slide_preview_service.dart';
import 'package:fluvie_presenter/src/sidebar/slide_sidebar.dart';
import 'package:obers_ui/obers_ui.dart' show OiThemeData, OiThemeScope;

/// Deterministic stand-in previews: one solid color per slide.
Future<ui.Image> _swatch(int slide) {
  const palette = [ui.Color(0xFF6C5CE7), ui.Color(0xFF55EFC4), ui.Color(0xFF1B2838)];
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 320, 180),
    ui.Paint()..color = palette[slide % palette.length],
  );
  return recorder.endRecording().toImage(320, 180);
}

Video _deck() => Video(
  width: 320,
  height: 180,
  scenes: const [
    Scene(duration: Time.seconds(2)),
    Scene(duration: Time.seconds(2)),
    Scene(duration: Time.seconds(2)),
  ],
);

Widget _scoped(
  SlidePreviewService service, {
  required Widget child,
  int currentSlide = 1,
  bool overviewOpen = false,
}) {
  final video = _deck();
  final container = ProviderContainer(
    overrides: [slidePlansProvider.overrideWithValue(compileSlidePlans(video))],
  );
  addTearDown(container.dispose);
  if (currentSlide > 0) {
    container.read(presentationControllerProvider.notifier).jumpToSlide(currentSlide);
  }
  container.read(sidebarVisibleProvider.notifier).visible = true;
  if (overviewOpen) container.read(overviewVisibleProvider.notifier).visible = true;
  return UncontrolledProviderScope(
    container: container,
    child: OiThemeScope(
      data: OiThemeData.dark(),
      child: ProviderScope(
        overrides: [slidePreviewServiceProvider.overrideWithValue(service)],
        child: child,
      ),
    ),
  );
}

Future<void> main() async {
  // Warm the shared cache with real images before any fake-async test zone:
  // toImage completes on engine callbacks the golden zone never drives.
  TestWidgetsFlutterBinding.ensureInitialized();
  final warm = SlidePreviewService(renderSlide: _swatch);
  await warm.pregenerateAll(3);

  // A second service whose slide 2 never arrives: the placeholder tile.
  final partial = SlidePreviewService(
    renderSlide: (slide) => slide == 2 ? Completer<ui.Image>().future : _swatch(slide),
  );
  await Future.wait([partial.preview(0), partial.preview(1)]);

  await goldenTest(
    'the sidebar lists previews with the current slide marked',
    fileName: 'slide_sidebar',
    builder: () => GoldenTestGroup(
      columns: 2,
      children: [
        GoldenTestScenario(
          name: 'all previews ready',
          child: _scoped(
            warm,
            child: const SizedBox(
              height: 360,
              child: Row(children: [SlideSidebar(aspectRatio: 16 / 9)]),
            ),
          ),
        ),
        GoldenTestScenario(
          name: 'one still a placeholder',
          child: _scoped(
            partial,
            child: const SizedBox(
              height: 360,
              child: Row(children: [SlideSidebar(aspectRatio: 16 / 9)]),
            ),
          ),
        ),
      ],
    ),
  );

  await goldenTest(
    'the overview grid shows every slide, current highlighted',
    fileName: 'overview_grid',
    builder: () => GoldenTestScenario(
      name: 'overview',
      child: _scoped(
        warm,
        overviewOpen: true,
        child: const SizedBox(
          width: 560,
          height: 240,
          child: OverviewGrid(aspectRatio: 16 / 9),
        ),
      ),
    ),
  );
}
