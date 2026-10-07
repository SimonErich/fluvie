import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'layout': 'canvas',
      'background': {'kind': 'color', 'color': '#14141C'},
      'children': [
        {
          'id': 'el-x',
          'type': 'Box',
          'color': '#FDCB6E',
          'transform': {'x': 0.1, 'y': 0.1, 'w': 0.1, 'h': 0.1},
        },
        {
          'id': 'el-g',
          'type': 'Group',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5},
          'children': [
            {
              'id': 'el-ga',
              'type': 'Box',
              'color': '#6C5CE7',
              'transform': {'x': 0.24, 'y': 0.5, 'w': 0.48, 'h': 1},
            },
            {
              'id': 'el-gb',
              'type': 'Box',
              'color': '#2ECC8F',
              'transform': {'x': 0.76, 'y': 0.5, 'w': 0.48, 'h': 1},
            },
          ],
        },
      ],
    },
  ],
  'editor': {
    'editorSchema': 1,
    'elements': {
      'el-g': {
        'block': {
          'kind': 'row',
          'spacing': 0.04,
          'mainAlign': 'start',
          'crossAlign': 'stretch',
          'equalSize': true,
        },
      },
    },
  },
};

final class _Harness {
  _Harness(this.container, this.viewport, this.history);

  final ProviderContainer container;
  final CanvasViewportController viewport;
  final DocumentHistory history;

  EditorDocument get document => history.document;

  Set<String> get selection => container.read(selectionProvider);

  String? get entered => container.read(enteredGroupProvider);
}

Future<_Harness> _pump(WidgetTester tester) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final viewport = CanvasViewportController();
  final history = DocumentHistory(EditorDocument.fromJson(_deck()));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: OiApp(
        title: 'test',
        theme: OiThemeData.dark(),
        home: Center(
          child: SizedBox(
            width: 320,
            height: 180,
            child: ListenableBuilder(
              listenable: history,
              builder: (context, _) => EditorCanvas(
                document: history.document,
                slide: 0,
                viewportController: viewport,
                fitMargin: 0,
                interactive: true,
                onCommand: history.dispatch,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return _Harness(container, viewport, history);
}

Offset _at(WidgetTester tester, _Harness harness, Offset point) =>
    tester.getTopLeft(find.byType(EditorCanvas)) + harness.viewport.toViewport(point);

Future<void> _enterGroup(WidgetTester tester, _Harness harness) async {
  final where = _at(tester, harness, const Offset(118, 90));
  await tester.tapAt(where);
  await tester.pump(const Duration(milliseconds: 40));
  await tester.tapAt(where);
  await tester.pump();
  expect(harness.entered, 'el-g');
}

Future<void> _drag(WidgetTester tester, _Harness harness, Offset from, Offset to) async {
  final gesture = await tester.startGesture(_at(tester, harness, from));
  await gesture.moveTo(_at(tester, harness, to));
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets('dragging a child out of its block releases it to the top level', (tester) async {
    final harness = await _pump(tester);
    final before = harness.document.toJson();
    await _enterGroup(tester, harness);
    await tester.tapAt(_at(tester, harness, const Offset(118, 90)));
    await tester.pump();
    await _drag(tester, harness, const Offset(118, 90), const Offset(300, 90));
    final document = harness.document;
    // The child left the group, id kept, right above it in z-order.
    expect(document.elementIdsInScene(0), ['el-x', 'el-g', 'el-ga']);
    expect(document.parentGroupOf('el-ga'), isNull);
    final transform = document.elementJson('el-ga')!['transform']! as Map;
    // Dragged +182 canvas px: the center lands at 118.4 + 182 = 300.4.
    expect((transform['x']! as num).toDouble(), closeTo(300.4 / 320, 1e-6));
    expect((transform['y']! as num).toDouble(), closeTo(0.5, 1e-6));
    expect((transform['w']! as num).toDouble(), closeTo(0.24, 1e-6));
    expect((transform['h']! as num).toDouble(), closeTo(0.5, 1e-6));
    // The block re-balanced around the remaining child.
    final rest = document.elementJson('el-gb')!['transform']! as Map;
    expect((rest['x']! as num).toDouble(), closeTo(0.5, 1e-6));
    expect((rest['w']! as num).toDouble(), closeTo(1, 1e-6));
    // The gesture exits the group and keeps the child selected.
    expect(harness.entered, isNull);
    expect(harness.selection, {'el-ga'});
    // One undo step restores the whole release.
    harness.history.undo();
    expect(harness.document.toJson(), before);
  });

  testWidgets('an in-bounds drag snaps the child back to its slot', (tester) async {
    final harness = await _pump(tester);
    await _enterGroup(tester, harness);
    await _drag(tester, harness, const Offset(118, 90), const Offset(150, 90));
    final transform = harness.document.elementJson('el-ga')!['transform']! as Map;
    expect((transform['x']! as num).toDouble(), closeTo(0.24, 1e-6));
    expect((transform['w']! as num).toDouble(), closeTo(0.48, 1e-6));
    expect(harness.document.parentGroupOf('el-ga'), 'el-g');
    expect(harness.entered, 'el-g');
  });

  testWidgets('a plain group never releases a dragged-out child', (tester) async {
    final harness = await _pump(tester);
    harness.history.dispatch(const ClearBlockCommand(ids: ['el-g']));
    await tester.pump();
    await _enterGroup(tester, harness);
    await _drag(tester, harness, const Offset(118, 90), const Offset(300, 90));
    expect(harness.document.parentGroupOf('el-ga'), 'el-g');
    expect(harness.entered, 'el-g');
  });
}
