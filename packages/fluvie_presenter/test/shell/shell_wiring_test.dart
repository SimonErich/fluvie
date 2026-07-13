import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';
import 'package:fluvie_presenter/src/shell/fullscreen/fullscreen_controller.dart';
import 'package:fluvie_presenter/src/shell/presenter_shell.dart';
import 'package:fluvie_presenter/src/shell/screen_blank.dart';
import 'package:fluvie_presenter/src/shell/ui_state.dart';

final class _FakeFullscreen extends FullscreenController {
  final List<String> calls = [];
  bool fullscreen = false;

  @override
  Future<void> enter() async {
    calls.add('enter');
    fullscreen = true;
  }

  @override
  Future<void> exit() async {
    calls.add('exit');
    fullscreen = false;
  }

  @override
  Future<bool> get isFullscreen async => fullscreen;
}

Video _deck() => Video(
  width: 320,
  height: 180,
  scenes: const [
    Scene(
      duration: Time.seconds(2),
      children: [Text('one', style: TextStyle(fontSize: 16))],
    ),
    Scene(
      duration: Time.seconds(2),
      children: [Text('two', style: TextStyle(fontSize: 16))],
    ),
  ],
);

(ProviderContainer, _FakeFullscreen, Widget) _present(Video video, {bool startFullscreen = false}) {
  final fullscreen = _FakeFullscreen();
  final container = ProviderContainer(
    overrides: [
      slidePlansProvider.overrideWithValue(compileSlidePlans(video)),
      fullscreenControllerProvider.overrideWithValue(fullscreen),
    ],
  );
  addTearDown(container.dispose);
  final widget = UncontrolledProviderScope(
    container: container,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: PresenterShell(video: video, startFullscreen: startFullscreen),
    ),
  );
  return (container, fullscreen, widget);
}

void main() {
  testWidgets('keys drive navigation end to end', (tester) async {
    final (container, _, widget) = _present(_deck());
    await tester.pumpWidget(widget);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(
      container.read(presentationControllerProvider).position,
      const PresentationPosition(1, 0),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(
      container.read(presentationControllerProvider).position,
      const PresentationPosition(0, 0),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(
      container.read(presentationControllerProvider).position,
      const PresentationPosition(1, 0),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(
      container.read(presentationControllerProvider).position,
      const PresentationPosition(0, 0),
    );
  });

  testWidgets('B covers the stage black; navigation clears it before moving', (tester) async {
    final (container, _, widget) = _present(_deck());
    await tester.pumpWidget(widget);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.pump();
    expect(container.read(blankScreenProvider), BlankScreen.black);

    // The first advance only clears the blank.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(container.read(blankScreenProvider), isNull);
    expect(
      container.read(presentationControllerProvider).position,
      const PresentationPosition(0, 0),
    );

    // The second one navigates.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(
      container.read(presentationControllerProvider).position,
      const PresentationPosition(1, 0),
    );
  });

  testWidgets('W toggles white, pressing it again clears', (tester) async {
    final (container, _, widget) = _present(_deck());
    await tester.pumpWidget(widget);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await tester.pump();
    expect(container.read(blankScreenProvider), BlankScreen.white);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await tester.pump();
    expect(container.read(blankScreenProvider), isNull);
  });

  testWidgets('F toggles fullscreen; Esc clears overlays before it exits', (tester) async {
    final (container, fullscreen, widget) = _present(_deck());
    await tester.pumpWidget(widget);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pump();
    expect(fullscreen.calls, ['enter']);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    // The blank went first; fullscreen stayed on.
    expect(container.read(blankScreenProvider), isNull);
    expect(fullscreen.calls, ['enter']);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(fullscreen.calls, ['enter', 'exit']);
  });

  testWidgets('O toggles the overview state; Esc closes it first', (tester) async {
    final (container, _, widget) = _present(_deck());
    await tester.pumpWidget(widget);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
    await tester.pump();
    expect(container.read(overviewVisibleProvider), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(container.read(overviewVisibleProvider), isFalse);
  });

  testWidgets('startFullscreen requests fullscreen once, post-frame', (tester) async {
    final (_, fullscreen, widget) = _present(_deck(), startFullscreen: true);
    await tester.pumpWidget(widget);
    await tester.pump();
    await tester.pump();
    expect(fullscreen.calls, ['enter']);
  });

  testWidgets('the FluvieSlides flags seed the chrome state', (tester) async {
    await tester.pumpWidget(FluvieSlides(_deck(), showSidebar: true, showNotes: true));
    await tester.pump();
    final context = tester.element(find.byType(PresenterShell));
    final container = ProviderScope.containerOf(context, listen: false);
    expect(container.read(sidebarVisibleProvider), isTrue);
    expect(container.read(notesVisibleProvider), isTrue);
  });

  testWidgets('a custom theme paints the stage', (tester) async {
    await tester.pumpWidget(
      FluvieSlides(
        _deck(),
        theme: const PresenterTheme(stageBackground: Color(0xFF224422)),
      ),
    );
    await tester.pump();
    final stage = tester.widget<ColoredBox>(
      find.descendant(of: find.byType(PresenterShell), matching: find.byType(ColoredBox)).first,
    );
    expect(stage.color, const Color(0xFF224422));
  });
}
