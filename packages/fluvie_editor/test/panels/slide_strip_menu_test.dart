import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show PointerDeviceKind, kSecondaryButton;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart' show SlidePreviewService;
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;

import '../commands/fake_system_clipboard.dart';

Map<String, Object?> _deck({int scenes = 3}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    for (var s = 0; s < scenes; s++)
      {
        'duration': '60f',
        'children': [
          {'id': 'el-$s', 'type': 'Text', 'text': 'slide $s'},
        ],
      },
  ],
};

Future<ui.Image> _stub(int slide) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = const ui.Color(0xFF123456),
  );
  return recorder.endRecording().toImage(4, 4);
}

final class _Harness {
  _Harness(this.history);
  final DocumentHistory history;
  final List<int> selected = [];
}

Future<_Harness> _pump(WidgetTester tester, {int scenes = 3, EditorClipboard? clipboard}) async {
  final service = SlidePreviewService(renderSlide: _stub);
  addTearDown(service.dispose);
  final history = DocumentHistory(EditorDocument.fromJson(_deck(scenes: scenes)));
  final harness = _Harness(history);
  await tester.pumpWidget(
    OiApp(
      title: 'test',
      theme: OiThemeData.dark(),
      home: ListenableBuilder(
        listenable: history,
        builder: (context, _) => SizedBox(
          width: 180,
          child: SlideStrip(
            document: history.document,
            current: 0,
            service: service,
            clipboard: clipboard,
            onSelect: harness.selected.add,
            onCommand: history.dispatch,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return harness;
}

Future<void> _rightClickTile(WidgetTester tester, int number) async {
  final where = tester.getCenter(find.text('$number'));
  final gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryButton,
  );
  await gesture.addPointer(location: where);
  await tester.pump();
  await gesture.down(where);
  await tester.pump();
  await gesture.up();
  // Removed right away so a test can right-click more than once.
  await gesture.removePointer();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('right-click on a tile opens the slide menu', (tester) async {
    await _pump(tester);
    await _rightClickTile(tester, 2);
    expect(find.text('Duplicate slide'), findsOneWidget);
    expect(find.text('Delete slide'), findsOneWidget);
    expect(find.text('Move slide up'), findsOneWidget);
    expect(find.text('Move slide down'), findsOneWidget);
  });

  testWidgets('duplicate acts on the clicked tile, not the current slide', (tester) async {
    final harness = await _pump(tester);
    await _rightClickTile(tester, 2);
    await tester.tap(find.text('Duplicate slide'));
    await tester.pumpAndSettle();
    expect(harness.history.document.sceneCount, 4);
    // The copy of slide 2 landed at index 2 with a fresh id.
    final copied = harness.history.document.elementIdsInScene(2).single;
    expect(copied, isNot('el-1'));
    expect(harness.history.document.elementJson(copied)!['text'], 'slide 1');
    // The strip put the copy on stage.
    expect(harness.selected, [2]);
  });

  testWidgets('move up reorders the clicked tile and follows it', (tester) async {
    final harness = await _pump(tester);
    await _rightClickTile(tester, 2);
    await tester.tap(find.text('Move slide up'));
    await tester.pumpAndSettle();
    expect(harness.history.document.elementIdsInScene(0), ['el-1']);
    expect(harness.selected, [0]);
  });

  testWidgets('move up is disabled on the first tile', (tester) async {
    final harness = await _pump(tester);
    await _rightClickTile(tester, 1);
    await tester.tap(find.text('Move slide up'));
    await tester.pumpAndSettle();
    expect(harness.history.canUndo, isFalse);
    expect(harness.history.document.elementIdsInScene(0), ['el-0']);
  });

  testWidgets('delete keeps at least one slide', (tester) async {
    final harness = await _pump(tester, scenes: 1);
    await _rightClickTile(tester, 1);
    await tester.tap(find.text('Delete slide'));
    await tester.pumpAndSettle();
    expect(harness.history.document.sceneCount, 1);
    expect(harness.history.canUndo, isFalse);
  });

  testWidgets('delete removes the clicked tile', (tester) async {
    final harness = await _pump(tester);
    await _rightClickTile(tester, 3);
    await tester.tap(find.text('Delete slide'));
    await tester.pumpAndSettle();
    expect(harness.history.document.sceneCount, 2);
    expect(harness.selected, [1]);
  });

  testWidgets('copy and paste slide travel the strip menu', (tester) async {
    final fake = FakeSystemClipboard()..install();
    addTearDown(() {
      fake
        ..text = null
        ..uninstall();
    });
    final harness = await _pump(tester, clipboard: EditorClipboard());
    await _rightClickTile(tester, 1);
    await tester.tap(find.text('Copy slide'));
    await tester.pumpAndSettle();
    // Copy alone never touches the document.
    expect(harness.history.canUndo, isFalse);

    await _rightClickTile(tester, 3);
    await tester.tap(find.text('Paste slide'));
    await tester.pumpAndSettle();
    expect(harness.history.document.sceneCount, 4);
    // The copy of slide 1 landed after the clicked tile with a fresh id.
    final pasted = harness.history.document.elementIdsInScene(3).single;
    expect(pasted, isNot('el-0'));
    expect(harness.history.document.elementJson(pasted)!['text'], 'slide 0');
    // The strip put the pasted slide on stage.
    expect(harness.selected, [3]);
  });

  testWidgets('without a clipboard the slide clipboard items are disabled', (tester) async {
    final harness = await _pump(tester);
    await _rightClickTile(tester, 1);
    await tester.tap(find.text('Copy slide'));
    await tester.pumpAndSettle();
    await _rightClickTile(tester, 1);
    await tester.tap(find.text('Paste slide'));
    await tester.pumpAndSettle();
    expect(harness.history.canUndo, isFalse);
    expect(harness.history.document.sceneCount, 3);
  });
}
