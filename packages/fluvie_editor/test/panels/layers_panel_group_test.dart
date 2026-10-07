import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiReorderable, OiThemeData;

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'children': [
        {
          'id': 'el-loose',
          'type': 'Text',
          'text': 'loose',
          'transform': {'x': 0.2, 'y': 0.3, 'w': 0.25, 'h': 0.2},
        },
        {
          'id': 'el-g',
          'type': 'Group',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5},
          'children': [
            {
              'id': 'el-ga',
              'type': 'Box',
              'color': '#AAAAAA',
              'transform': {'x': 0.3, 'y': 0.5, 'w': 0.4, 'h': 0.4},
            },
            {
              'id': 'el-gb',
              'type': 'Box',
              'color': '#BBBBBB',
              'transform': {'x': 0.7, 'y': 0.5, 'w': 0.4, 'h': 0.4},
            },
          ],
        },
      ],
    },
  ],
  'editor': {
    'editorSchema': 1,
    'elements': {
      'el-loose': {'name': 'Loose'},
      'el-g': {'name': 'Badge'},
      'el-ga': {'name': 'Card'},
      'el-gb': {'name': 'Accent'},
    },
  },
};

final class _Harness {
  _Harness(this.container, this.history);
  final ProviderContainer container;
  final DocumentHistory history;
}

Future<_Harness> _pump(WidgetTester tester) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final history = DocumentHistory(EditorDocument.fromJson(_deck()));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: OiApp(
        title: 'test',
        theme: OiThemeData.dark(),
        home: ListenableBuilder(
          listenable: history,
          builder: (context, _) => SizedBox(
            width: 220,
            child: LayersPanel(document: history.document, slide: 0, onCommand: history.dispatch),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return _Harness(container, history);
}

void main() {
  testWidgets('a group renders as a collapsed subtree row', (tester) async {
    await _pump(tester);
    expect(find.text('Badge'), findsOneWidget);
    expect(find.text('Loose'), findsOneWidget);
    expect(find.text('Card'), findsNothing);
    expect(find.text('Accent'), findsNothing);
    expect(find.bySemanticsLabel('Expand Badge'), findsOneWidget);
  });

  testWidgets('expanding shows indented children, topmost first', (tester) async {
    await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Expand Badge'));
    await tester.pump();
    expect(find.text('Card'), findsOneWidget);
    expect(find.text('Accent'), findsOneWidget);
    // Topmost first inside the subtree: Accent (top) above Card.
    expect(
      tester.getTopLeft(find.text('Accent')).dy,
      lessThan(tester.getTopLeft(find.text('Card')).dy),
    );
    // Children indent past the top-level rows (Loose has no chevron, so it
    // shares the plain-row label offset).
    expect(
      tester.getTopLeft(find.text('Card')).dx,
      greaterThan(tester.getTopLeft(find.text('Loose')).dx),
    );

    await tester.tap(find.bySemanticsLabel('Collapse Badge'));
    await tester.pump();
    expect(find.text('Card'), findsNothing);
  });

  testWidgets('child toggles go through the command layer', (tester) async {
    final harness = await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Expand Badge'));
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Lock Card'));
    await tester.pump();
    expect(harness.history.document.elementMeta('el-ga')['locked'], isTrue);

    await tester.tap(find.bySemanticsLabel('Hide Accent'));
    await tester.pump();
    expect(harness.history.document.elementJson('el-gb')?['visible'], false);

    harness.history
      ..undo()
      ..undo();
    expect(harness.history.document.elementMeta('el-ga')['locked'], isNull);
    expect(harness.history.document.elementJson('el-gb')?.containsKey('visible'), isFalse);
  });

  testWidgets('tapping a child selects it and enters its group', (tester) async {
    final harness = await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Expand Badge'));
    await tester.pump();
    await tester.tap(find.text('Card'));
    await tester.pump();
    expect(harness.container.read(selectionProvider), {'el-ga'});
    expect(harness.container.read(enteredGroupProvider), 'el-g');

    await tester.tap(find.text('Loose'));
    await tester.pump();
    expect(harness.container.read(selectionProvider), {'el-loose'});
    expect(harness.container.read(enteredGroupProvider), isNull);
  });

  testWidgets('one flat list reorders the group children in place', (tester) async {
    final harness = await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Expand Badge'));
    await tester.pump();
    final reorderable = find.byType(OiReorderable);
    expect(reorderable, findsOneWidget);
    // Flat rows: Badge (0), Accent (1), Card (2), Loose (3). Accent dropped
    // below Card stays inside the group at z 0.
    tester.widget<OiReorderable>(reorderable).onReorder(1, 3);
    await tester.pump();
    expect(harness.history.document.childIdsOfGroup('el-g'), ['el-gb', 'el-ga']);
    expect(harness.history.document.elementIdsInScene(0), ['el-loose', 'el-g']);
  });

  testWidgets('dragging a row between the children moves it into the group', (tester) async {
    final harness = await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Expand Badge'));
    await tester.pump();
    final before = SceneGeometry.of(harness.history.document, 0).rectOf('el-loose')!;
    // Loose (3) dropped between Accent and Card enters the group at z 1.
    tester.widget<OiReorderable>(find.byType(OiReorderable)).onReorder(3, 2);
    await tester.pump();
    final document = harness.history.document;
    expect(document.parentGroupOf('el-loose'), 'el-g');
    expect(document.childIdsOfGroup('el-g'), ['el-ga', 'el-loose', 'el-gb']);
    // The 5.3 math keeps the pixels: nothing moves on screen.
    final after = SceneGeometry.of(document, 0, enteredGroup: 'el-g').rectOf('el-loose')!;
    expect(after.center.dx, closeTo(before.center.dx, 1e-6));
    expect(after.center.dy, closeTo(before.center.dy, 1e-6));
    expect(harness.history.undoLabel, 'Move el-loose into group');
  });

  testWidgets('dragging a child to a top-level slot promotes it', (tester) async {
    final harness = await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Expand Badge'));
    await tester.pump();
    final before = SceneGeometry.of(
      harness.history.document,
      0,
      enteredGroup: 'el-g',
    ).rectOf('el-ga')!;
    // Card (2) dropped above Badge leaves the group for the top level.
    tester.widget<OiReorderable>(find.byType(OiReorderable)).onReorder(2, 0);
    await tester.pump();
    final document = harness.history.document;
    expect(document.parentGroupOf('el-ga'), isNull);
    expect(document.elementIdsInScene(0), ['el-loose', 'el-g', 'el-ga']);
    final after = SceneGeometry.of(document, 0).rectOf('el-ga')!;
    expect(after.center.dx, closeTo(before.center.dx, 1e-6));
    expect(after.center.dy, closeTo(before.center.dy, 1e-6));
    expect(harness.history.undoLabel, 'Move el-ga out of group');
  });

  testWidgets('dragging the group row itself reorders at the top level', (tester) async {
    final harness = await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Expand Badge'));
    await tester.pump();
    // Badge (0) dropped below Loose moves the whole group to the bottom.
    tester.widget<OiReorderable>(find.byType(OiReorderable)).onReorder(0, 4);
    await tester.pump();
    expect(harness.history.document.elementIdsInScene(0), ['el-g', 'el-loose']);
    expect(harness.history.document.childIdsOfGroup('el-g'), ['el-ga', 'el-gb']);
  });

  testWidgets('a drop back in place dispatches nothing', (tester) async {
    final harness = await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Expand Badge'));
    await tester.pump();
    tester.widget<OiReorderable>(find.byType(OiReorderable)).onReorder(1, 1);
    await tester.pump();
    expect(harness.history.canUndo, isFalse);
  });

  testWidgets('a block group row carries its kind as a suffix chip', (tester) async {
    final harness = await _pump(tester);
    expect(find.text('grid'), findsNothing);
    harness.history.dispatch(
      SetBlockParamsCommand(groupId: 'el-g', block: BlockSpec.defaults(BlockKind.grid)),
    );
    await tester.pump();
    expect(find.text('grid'), findsOneWidget);
    // The chip sits on the group's row, next to its name.
    expect(
      tester.getTopLeft(find.text('grid')).dy,
      closeTo(tester.getTopLeft(find.text('Badge')).dy, 8),
    );
  });

  testWidgets('renaming a child writes its metadata', (tester) async {
    final harness = await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Expand Badge'));
    await tester.pump();
    await tester.tap(find.text('Card'));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.text('Card'));
    await tester.pumpAndSettle();
    expect(find.byType(EditableText), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'Front card');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(harness.history.document.elementMeta('el-ga')['name'], 'Front card');
  });
}
