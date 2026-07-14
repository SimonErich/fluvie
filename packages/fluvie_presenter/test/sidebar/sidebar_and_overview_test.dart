import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';
import 'package:fluvie_presenter/src/shell/presenter_shell.dart';
import 'package:fluvie_presenter/src/shell/ui_state.dart';
import 'package:fluvie_presenter/src/sidebar/slide_preview_service.dart';
import 'package:fluvie_presenter/src/sidebar/slide_preview_tile.dart';

Future<ui.Image> _pixel(int _) {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 8, 8),
    ui.Paint()..color = const ui.Color(0xFF446688),
  );
  return recorder.endRecording().toImage(8, 8);
}

Video _deck({int scenes = 3}) => Video(
  width: 320,
  height: 180,
  scenes: [
    for (var s = 0; s < scenes; s++)
      Scene(
        duration: const Time.seconds(2),
        children: [Text('slide $s', style: const TextStyle(fontSize: 16))],
      ),
  ],
);

(ProviderContainer, SlidePreviewService, Widget) _present(Video video) {
  final service = SlidePreviewService(renderSlide: _pixel);
  addTearDown(service.dispose);
  final container = ProviderContainer(
    overrides: [slidePlansProvider.overrideWithValue(compileSlidePlans(video))],
  );
  addTearDown(container.dispose);
  final widget = UncontrolledProviderScope(
    container: container,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: PresenterShell(video: video, previewService: service),
    ),
  );
  return (container, service, widget);
}

void main() {
  testWidgets('a swapped deck invalidates the preview cache', (tester) async {
    final service = SlidePreviewService(renderSlide: _pixel);
    addTearDown(service.dispose);
    final video = _deck();
    final container = ProviderContainer(
      overrides: [slidePlansProvider.overrideWithValue(compileSlidePlans(video))],
    );
    addTearDown(container.dispose);
    Widget host(Video deck) => UncontrolledProviderScope(
      container: container,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: PresenterShell(video: deck, previewService: service),
      ),
    );
    await tester.pumpWidget(host(video));
    await tester.runAsync(() => service.preview(0));
    expect(service.peek(0), isNotNull);

    // A new deck instance means every cached thumbnail is stale.
    await tester.pumpWidget(host(_deck()));
    expect(service.peek(0), isNull);
  });

  testWidgets('keyboard focus follows the current slide, keys keep working', (tester) async {
    final (container, _, widget) = _present(_deck());
    await tester.pumpWidget(widget);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.pump();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(tester.binding.focusManager.primaryFocus?.debugLabel, 'current slide tile');

    // The followed focus sits under the shell's key handler, so input
    // still drives navigation.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(
      container.read(presentationControllerProvider).position,
      const PresentationPosition(2, 0),
    );
  });

  testWidgets('the sidebar toggles with T, lists tiles, and jumps on tap', (tester) async {
    final (container, _, widget) = _present(_deck());
    await tester.pumpWidget(widget);
    await tester.pump();
    expect(find.byType(SlidePreviewTile), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.pump();
    await tester.pump();
    expect(find.byType(SlidePreviewTile), findsNWidgets(3));

    await tester.tap(find.byType(SlidePreviewTile).at(1), warnIfMissed: false);
    await tester.pump();
    expect(
      container.read(presentationControllerProvider).position,
      const PresentationPosition(1, 0),
    );
    // Jumping from the sidebar keeps it open.
    expect(find.byType(SlidePreviewTile), findsNWidgets(3));
  });

  testWidgets('tiles show placeholders first, then the rendered preview', (tester) async {
    final completer = Completer<ui.Image>();
    final service = SlidePreviewService(renderSlide: (_) => completer.future);
    addTearDown(service.dispose);
    final video = _deck(scenes: 1);
    final container = ProviderContainer(
      overrides: [
        slidePlansProvider.overrideWithValue(compileSlidePlans(video)),
        sidebarVisibleProvider.overrideWith(() => UiToggle(initiallyVisible: true)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: PresenterShell(video: video, previewService: service),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(RawImage), findsNothing);

    // Picture.toImage is real engine work: produce the pixel outside the
    // test's fake clock, then hand it to the pending renderer.
    final image = await tester.runAsync(() => _pixel(0));
    completer.complete(image);
    await tester.pump();
    await tester.pump();
    expect(find.byType(RawImage), findsOneWidget);
  });

  testWidgets('the overview grid opens with O, picks a slide, and closes', (tester) async {
    final (container, _, widget) = _present(_deck());
    await tester.pumpWidget(widget);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
    await tester.pump();
    await tester.pump();
    expect(find.byType(GridView), findsOneWidget);
    expect(find.byType(SlidePreviewTile), findsNWidgets(3));

    await tester.tap(find.byType(SlidePreviewTile).at(2), warnIfMissed: false);
    await tester.pump();
    expect(
      container.read(presentationControllerProvider).position,
      const PresentationPosition(2, 0),
    );
    expect(find.byType(GridView), findsNothing);
  });

  testWidgets('the showSidebar flag opens the sidebar from the start', (tester) async {
    await tester.pumpWidget(FluvieSlides(_deck(), showSidebar: true));
    await tester.pump();
    await tester.pump();
    expect(find.byType(SlidePreviewTile), findsNWidgets(3));
  });
}
