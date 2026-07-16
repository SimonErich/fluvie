import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';
import 'package:fluvie_presenter/src/shell/presenter_shell.dart';
import 'package:fluvie_presenter/src/shell/ui_state.dart';
import 'package:obers_ui/obers_ui.dart' show OiIconButton, OiIcons;

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

(ProviderContainer, Widget) _present(
  Video video, {
  Size viewport = const Size(800, 600),
  VoidCallback? onClose,
}) {
  final plans = compileSlidePlans(video);
  final container = ProviderContainer(
    overrides: [
      slidePlansProvider.overrideWithValue(plans),
      slideNotesProvider.overrideWithValue(compileNotes(video, plans)),
    ],
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
          child: PresenterShell(video: video, onClose: onClose),
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

  testWidgets('the HUD buttons drive the chrome without the keyboard', (tester) async {
    final (container, widget) = _present(_deck());
    await tester.pumpWidget(widget);
    await tester.pump();

    Future<void> tapButton(IconData icon) async {
      await tester.tap(
        find.byWidgetPredicate((w) => w is OiIconButton && w.icon == icon),
        warnIfMissed: false,
      );
      await tester.pump();
    }

    expect(container.read(sidebarVisibleProvider), isFalse);
    await tapButton(OiIcons.panelLeft);
    expect(container.read(sidebarVisibleProvider), isTrue);

    expect(container.read(notesVisibleProvider), isFalse);
    await tapButton(OiIcons.notepadText);
    expect(container.read(notesVisibleProvider), isTrue);

    await tapButton(OiIcons.layoutGrid);
    expect(container.read(overviewVisibleProvider), isTrue);
    // The overview covers the strip; Esc closes it again.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(container.read(overviewVisibleProvider), isFalse);

    // On mobile (the test default platform) the speaker surface is the
    // notes panel; the speaker button routes there.
    container.read(notesVisibleProvider.notifier).visible = false;
    await tapButton(OiIcons.presentation);
    expect(container.read(notesVisibleProvider), isTrue);

    // H hides the whole HUD, buttons included.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.pump();
    expect(find.byType(OiIconButton), findsNothing);
  });

  testWidgets('a close intention gets its own button, set apart on the right', (tester) async {
    var closed = 0;
    final (_, widget) = _present(_deck(), onClose: () => closed++);
    await tester.pumpWidget(widget);
    await tester.pump();

    final close = find.byWidgetPredicate((w) => w is OiIconButton && w.icon == OiIcons.x);
    expect(close, findsOneWidget);
    // Set apart: a clear gap between the strip and the close button.
    final fullscreen = find.byWidgetPredicate(
      (w) => w is OiIconButton && w.icon == OiIcons.maximize,
    );
    final gap = tester.getTopLeft(close).dx - tester.getTopRight(fullscreen).dx;
    expect(gap, greaterThanOrEqualTo(12));

    await tester.tap(close, warnIfMissed: false);
    await tester.pump();
    expect(closed, 1);
  });

  testWidgets('no close intention, no close button', (tester) async {
    final (_, widget) = _present(_deck());
    await tester.pumpWidget(widget);
    await tester.pump();
    expect(find.byWidgetPredicate((w) => w is OiIconButton && w.icon == OiIcons.x), findsNothing);
  });

  testWidgets('fullscreen hides the strip after 4s; hovering revives it for 5s', (tester) async {
    final (container, widget) = _present(_deck());
    await tester.pumpWidget(widget);
    await tester.pump();

    double stripOpacity() => tester
        .widget<AnimatedOpacity>(
          find.ancestor(
            of: find.byType(OiIconButton).first,
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;

    expect(stripOpacity(), 1);
    container.read(fullscreenActiveProvider.notifier).visible = true;
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(stripOpacity(), 1, reason: 'still within the 4s grace');
    await tester.pump(const Duration(milliseconds: 1100));
    expect(stripOpacity(), 0, reason: 'hidden 4s after entering fullscreen');

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await tester.pump();
    await mouse.moveTo(tester.getCenter(find.byType(OiIconButton).first));
    await tester.pump();
    expect(stripOpacity(), 1, reason: 'hovering the corner reveals the strip');
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 5100));
    expect(stripOpacity(), 0, reason: 'hidden again 5s after the reveal');

    container.read(fullscreenActiveProvider.notifier).visible = false;
    await tester.pump();
    expect(stripOpacity(), 1, reason: 'leaving fullscreen restores the strip');
  });
}
