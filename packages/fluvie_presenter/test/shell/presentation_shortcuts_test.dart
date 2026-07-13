import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_presenter/src/shell/presentation_shortcuts.dart';

final class _Recorder {
  final List<String> calls = [];

  PresenterHandlers get handlers => PresenterHandlers(
    onNext: () => calls.add('next'),
    onBack: () => calls.add('back'),
    onFirst: () => calls.add('first'),
    onLast: () => calls.add('last'),
    onJump: (slide) => calls.add('jump:$slide'),
    onToggleFullscreen: () => calls.add('fullscreen'),
    onEscape: () => calls.add('escape'),
    onOverview: () => calls.add('overview'),
    onSpeakerWindow: () => calls.add('speaker'),
    onBlackScreen: () => calls.add('black'),
    onWhiteScreen: () => calls.add('white'),
    onToggleHud: () => calls.add('hud'),
  );
}

void main() {
  Future<_Recorder> pump(WidgetTester tester) async {
    final recorder = _Recorder();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: PresentationShortcuts(
          handlers: recorder.handlers,
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();
    return recorder;
  }

  testWidgets('every next binding advances', (tester) async {
    final recorder = await pump(tester);
    for (final key in [
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.pageDown,
      LogicalKeyboardKey.enter,
    ]) {
      await tester.sendKeyEvent(key);
    }
    expect(recorder.calls, List.filled(5, 'next'));
  });

  testWidgets('every back binding retreats, including Shift+Space', (tester) async {
    final recorder = await pump(tester);
    for (final key in [
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.pageUp,
    ]) {
      await tester.sendKeyEvent(key);
    }
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(recorder.calls, List.filled(4, 'back'));
  });

  testWidgets('Home and End jump to the deck edges', (tester) async {
    final recorder = await pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    expect(recorder.calls, ['first', 'last']);
  });

  testWidgets('digits then Enter jump to the one-based slide number', (tester) async {
    final recorder = await pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    // Slide "12" as presented → index 11.
    expect(recorder.calls, ['jump:11']);
    // The buffer cleared: a plain Enter advances again.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(recorder.calls, ['jump:11', 'next']);
  });

  testWidgets('Escape clears a pending jump before it escapes', (tester) async {
    final recorder = await pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(recorder.calls, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(recorder.calls, ['escape']);
  });

  testWidgets('the chrome keys fire their handlers', (tester) async {
    final recorder = await pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyEvent(LogicalKeyboardKey.period);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    expect(recorder.calls, [
      'fullscreen',
      'fullscreen',
      'overview',
      'speaker',
      'black',
      'black',
      'white',
      'hud',
    ]);
  });

  testWidgets('tap advances, swipes navigate', (tester) async {
    final recorder = await pump(tester);
    await tester.tap(find.byType(SizedBox));
    expect(recorder.calls, ['next']);
    await tester.fling(find.byType(SizedBox), const Offset(-300, 0), 1200);
    await tester.pumpAndSettle();
    expect(recorder.calls, ['next', 'next']);
    await tester.fling(find.byType(SizedBox), const Offset(300, 0), 1200);
    await tester.pumpAndSettle();
    expect(recorder.calls, ['next', 'next', 'back']);
  });
}
