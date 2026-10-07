import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart' show SlideTransport, TransportKeys;

void main() {
  SlideTransport transport({int frame = 0}) {
    final created = SlideTransport(fps: 30, length: 120, initialFrame: frame);
    addTearDown(created.dispose);
    return created;
  }

  Future<void> pump(
    WidgetTester tester, {
    required SlideTransport transport,
    required bool panelOpen,
    List<int> bounds = const [],
    VoidCallback? onAdvanceSlide,
    Widget? child,
  }) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: TransportKeys(
          transport: transport,
          panelOpen: panelOpen,
          stepBounds: () => bounds,
          onAdvanceSlide: onAdvanceSlide,
          child: child ?? const Focus(autofocus: true, child: SizedBox.expand()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('with the panel open, Space toggles play and pause', (tester) async {
    final shared = transport();
    await pump(tester, transport: shared, panelOpen: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(shared.isPlaying, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(shared.isPlaying, isFalse);
  });

  testWidgets('holding Space does not retrigger on key repeats', (tester) async {
    final shared = transport();
    await pump(tester, transport: shared, panelOpen: true);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    expect(shared.isPlaying, isTrue);
  });

  testWidgets('with the panel closed, Space steps to the next landing', (tester) async {
    final shared = transport();
    await pump(tester, transport: shared, panelOpen: false, bounds: [30, 60]);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(shared.isPlaying, isFalse);
    expect(shared.frame, 30);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(shared.frame, 60);
  });

  testWidgets('past the last landing, Space asks for the next slide', (tester) async {
    final shared = transport(frame: 60);
    var advanced = 0;
    await pump(
      tester,
      transport: shared,
      panelOpen: false,
      bounds: [30, 60],
      onAdvanceSlide: () => advanced++,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(advanced, 1);
    expect(shared.frame, 60);
  });

  testWidgets('a slide with no landings advances immediately', (tester) async {
    final shared = transport();
    var advanced = 0;
    await pump(
      tester,
      transport: shared,
      panelOpen: false,
      onAdvanceSlide: () => advanced++,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(advanced, 1);
  });

  testWidgets('Space keeps typing spaces inside a text field', (tester) async {
    final shared = transport();
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await pump(
      tester,
      transport: shared,
      panelOpen: true,
      child: EditableText(
        controller: controller,
        focusNode: focusNode,
        autofocus: true,
        style: const TextStyle(),
        cursorColor: const Color(0xFFFFFFFF),
        backgroundCursorColor: const Color(0xFFFFFFFF),
      ),
    );
    expect(focusNode.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(shared.isPlaying, isFalse);
  });

  testWidgets('other keys pass through untouched', (tester) async {
    final shared = transport();
    await pump(tester, transport: shared, panelOpen: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(shared.isPlaying, isFalse);
    expect(shared.frame, 0);
  });
}
