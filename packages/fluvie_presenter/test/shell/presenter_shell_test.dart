import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';
import 'package:fluvie_presenter/src/shell/presenter_shell.dart';
import 'package:fluvie_presenter/src/shell/ui_state.dart';

Video _deck({int scenes = 2}) => Video(
  width: 320,
  height: 180,
  scenes: [
    for (var s = 0; s < scenes; s++)
      Scene(
        duration: const Time.seconds(2),
        children: [
          Text('slide $s', style: const TextStyle(fontSize: 16)),
          if (s == 0) Stop.single(child: const SizedBox(width: 4, height: 4)),
        ],
      ),
  ],
);

(ProviderContainer, Widget) _present(Video video, {Size viewport = const Size(800, 600)}) {
  final container = ProviderContainer(
    overrides: [slidePlansProvider.overrideWithValue(compileSlidePlans(video))],
  );
  addTearDown(container.dispose);
  final widget = UncontrolledProviderScope(
    container: container,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: viewport.width,
          height: viewport.height,
          child: PresenterShell(video: video),
        ),
      ),
    ),
  );
  return (container, widget);
}

void main() {
  testWidgets('stages the slide letterboxed with the HUD on top', (tester) async {
    final (_, widget) = _present(_deck());
    await tester.pumpWidget(widget);
    await tester.pump();
    expect(find.byType(SlideView), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('the counter follows navigation', (tester) async {
    final (container, widget) = _present(_deck());
    await tester.pumpWidget(widget);
    await tester.pump();
    container.read(presentationControllerProvider.notifier).jumpToSlide(1);
    await tester.pump();
    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('the HUD hides when toggled off', (tester) async {
    final (container, widget) = _present(_deck());
    await tester.pumpWidget(widget);
    await tester.pump();
    container.read(hudVisibleProvider.notifier).toggle();
    await tester.pump();
    expect(find.text('1 / 2'), findsNothing);
  });

  testWidgets('letterboxing fits the canvas into any viewport aspect', (tester) async {
    // A 16:9 deck inside a square viewport: the stage width is the limit.
    final (_, widget) = _present(_deck(), viewport: const Size(300, 300));
    await tester.pumpWidget(widget);
    await tester.pump();
    // getRect applies the FittedBox transform, so this is the painted rect.
    final videoBox = tester.getRect(find.byType(Video));
    expect(videoBox.width / videoBox.height, closeTo(16 / 9, 0.01));
    expect(videoBox.width, closeTo(300, 0.01));
  });
}
