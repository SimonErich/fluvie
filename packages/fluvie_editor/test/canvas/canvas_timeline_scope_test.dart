// The transport's face in the command registry. Until the canvas hands the
// scope a playhead and a seek, every timeline verb reads as disabled on a
// surface that plainly has a playhead.

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;

/// Two scenes of 60 and 90 frames, so the edits sit at 0, 60 and 150.
Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'children': [
        {'id': 'el-a', 'type': 'Text', 'text': 'one'},
      ],
    },
    {
      'duration': '90f',
      'children': [
        {'id': 'el-b', 'type': 'Text', 'text': 'two'},
      ],
    },
  ],
};

final class _Harness {
  _Harness(this.container, this.transport);
  final ProviderContainer container;
  final SlideTransport transport;

  TimelineMarks get marks => container.read(timelineMarksProvider);
}

Future<_Harness> _pump(WidgetTester tester, {bool withTransport = true}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final document = EditorDocument.fromJson(_deck());
  final transport = SlideTransport(fps: 30, length: 150);
  addTearDown(transport.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: OiApp(
        title: 'test',
        theme: OiThemeData.dark(),
        home: EditorCanvas(
          document: document,
          slide: 0,
          fitMargin: 0,
          interactive: true,
          wholeDocument: withTransport,
          transport: withTransport ? transport : null,
          onCommand: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
  // The lanes and the canvas both take keys; the canvas has to hold focus
  // for the registry to see one at all.
  await tester.tapAt(tester.getCenter(find.byType(EditorCanvas)));
  await tester.pump();
  return _Harness(container, transport);
}

void main() {
  testWidgets('I marks in at the playhead', (tester) async {
    final harness = await _pump(tester);
    harness.transport.seek(42);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await tester.pump();

    expect(harness.marks.markIn, 42);
  });

  testWidgets('O marks out, and the pair reads as a span', (tester) async {
    final harness = await _pump(tester);
    harness.transport.seek(20);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    harness.transport.seek(90);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
    await tester.pump();

    expect(harness.marks.span, (start: 20, end: 90));
  });

  testWidgets('Shift+I goes to the in point', (tester) async {
    final harness = await _pump(tester);
    harness.container.read(timelineMarksProvider.notifier).set(markIn: 33);
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(harness.transport.frame, 33);
  });

  testWidgets('Page Down walks to the next edit and stops at the last', (tester) async {
    final harness = await _pump(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pump();
    expect(harness.transport.frame, 60);

    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pump();
    expect(harness.transport.frame, 150);

    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pump();
    expect(harness.transport.frame, 150, reason: 'the last edit is the last');
  });

  testWidgets('Page Up walks back', (tester) async {
    final harness = await _pump(tester);
    harness.transport.seek(150);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.pump();

    expect(harness.transport.frame, 60);
  });

  testWidgets('a stage with no transport marks nothing rather than marking zero', (tester) async {
    // Frame zero is a real position. A surface with no playhead has to read
    // as having none, or the verb would silently write a mark nobody aimed.
    final harness = await _pump(tester, withTransport: false);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await tester.pump();

    expect(harness.marks.markIn, isNull);
  });
}
