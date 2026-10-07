import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiSelect, OiSwitch, OiThemeData;

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'layout': 'canvas',
      'children': [
        {
          'id': 'el-b',
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
        {
          'id': 'el-plain',
          'type': 'Group',
          'transform': {'x': 0.5, 'y': 0.85, 'w': 0.4, 'h': 0.2},
          'children': [
            {
              'id': 'el-pa',
              'type': 'Box',
              'color': '#E17055',
              'transform': {'x': 0.25, 'y': 0.5, 'w': 0.4, 'h': 0.8},
            },
            {
              'id': 'el-pb',
              'type': 'Box',
              'color': '#0984E3',
              'transform': {'x': 0.75, 'y': 0.5, 'w': 0.4, 'h': 0.8},
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
  _Harness(this.container, this.history, this.commands);
  final ProviderContainer container;
  final DocumentHistory history;
  final List<EditorCommand> commands;
}

Future<_Harness> _pump(WidgetTester tester, {required String selected}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final history = DocumentHistory(EditorDocument.fromJson(_deck()));
  final commands = <EditorCommand>[];
  container.read(selectionProvider.notifier).select({selected});
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: OiApp(
        title: 'test',
        theme: OiThemeData.dark(),
        home: ListenableBuilder(
          listenable: history,
          builder: (context, _) => Row(
            children: [
              const Spacer(),
              SizedBox(
                width: 280,
                child: EditorInspector(
                  document: history.document,
                  slide: 0,
                  onCommand: (command) {
                    commands.add(command);
                    history.dispatch(command);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return _Harness(container, history, commands);
}

OiSelect<String> _kindSelect(WidgetTester tester) =>
    tester.widget<OiSelect<String>>(find.byKey(const ValueKey('block-kind')));

Future<void> _commitField(WidgetTester tester, Key key, String text) async {
  final field = find.descendant(of: find.byKey(key), matching: find.byType(EditableText));
  await tester.enterText(field, text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

void main() {
  testWidgets('a non-group selection shows no Block section', (tester) async {
    await _pump(tester, selected: 'el-b');
    expect(find.text('Block'), findsNothing);
  });

  testWidgets('a block group shows its kind and params', (tester) async {
    await _pump(tester, selected: 'el-g');
    expect(find.text('Block'), findsOneWidget);
    expect(_kindSelect(tester).value, 'row');
    expect(find.byKey(const ValueKey('block-spacing')), findsOneWidget);
    expect(find.byKey(const ValueKey('block-mainAlign')), findsOneWidget);
    expect(find.byKey(const ValueKey('block-crossAlign')), findsOneWidget);
    expect(find.byKey(const ValueKey('block-equalSize')), findsOneWidget);
  });

  testWidgets('a plain group offers the kind picker with none selected', (tester) async {
    final harness = await _pump(tester, selected: 'el-plain');
    expect(find.text('Block'), findsOneWidget);
    expect(_kindSelect(tester).value, 'none');
    expect(find.byKey(const ValueKey('block-spacing')), findsNothing);
    _kindSelect(tester).onChanged!('column');
    await tester.pump();
    expect(harness.history.document.blockOf('el-plain')?.kind, BlockKind.column);
    // The pick arranged the children immediately.
    final transform =
        harness.history.document.elementJson('el-pa')!['transform']! as Map<String, Object?>;
    expect((transform['y']! as num).toDouble(), closeTo(0.24, 1e-9));
  });

  testWidgets('switching the kind restarts from that kind defaults', (tester) async {
    final harness = await _pump(tester, selected: 'el-g');
    _kindSelect(tester).onChanged!('grid');
    await tester.pump();
    final block = harness.history.document.blockOf('el-g');
    expect(block?.kind, BlockKind.grid);
    expect(block?.columns, 2);
  });

  testWidgets('choosing none clears the block and keeps the geometry', (tester) async {
    final harness = await _pump(tester, selected: 'el-g');
    final before = harness.history.document.elementJson('el-ga');
    _kindSelect(tester).onChanged!('none');
    await tester.pump();
    expect(harness.history.document.blockOf('el-g'), isNull);
    expect(harness.history.document.elementJson('el-ga'), before);
  });

  testWidgets('a param field edits merge-grouped and reflows', (tester) async {
    final harness = await _pump(tester, selected: 'el-g');
    await _commitField(tester, const ValueKey('block-spacing'), '0.1');
    final command = harness.commands.whereType<SetBlockParamsCommand>().single;
    expect(command.mergeGroup, isNotNull);
    expect(harness.history.document.blockOf('el-g')?.spacing, 0.1);
    final transform =
        harness.history.document.elementJson('el-ga')!['transform']! as Map<String, Object?>;
    expect((transform['w']! as num).toDouble(), closeTo(0.45, 1e-9));
  });

  testWidgets('the grid params surface columns', (tester) async {
    final harness = await _pump(tester, selected: 'el-g');
    _kindSelect(tester).onChanged!('grid');
    await tester.pump();
    await _commitField(tester, const ValueKey('block-columns'), '3');
    expect(harness.history.document.blockOf('el-g')?.columns, 3);
  });

  testWidgets('the equal-size switch writes through', (tester) async {
    final harness = await _pump(tester, selected: 'el-g');
    tester.widget<OiSwitch>(find.byKey(const ValueKey('block-equalSize'))).onChanged!(false);
    await tester.pump();
    expect(harness.history.document.blockOf('el-g')?.equalSize, isFalse);
  });

  testWidgets('the align selects write through', (tester) async {
    final harness = await _pump(tester, selected: 'el-g');
    tester.widget<OiSelect<String>>(find.byKey(const ValueKey('block-mainAlign'))).onChanged!(
      'spaceBetween',
    );
    await tester.pump();
    expect(harness.history.document.blockOf('el-g')?.mainAlign, BlockMainAlign.spaceBetween);
    tester.widget<OiSelect<String>>(find.byKey(const ValueKey('block-crossAlign'))).onChanged!(
      'center',
    );
    await tester.pump();
    expect(harness.history.document.blockOf('el-g')?.crossAlign, BlockCrossAlign.center);
  });

  testWidgets('list, split, and title params surface their fields', (tester) async {
    final harness = await _pump(tester, selected: 'el-g');
    _kindSelect(tester).onChanged!('list');
    await tester.pump();
    await _commitField(tester, const ValueKey('block-itemHeight'), '0.25');
    expect(harness.history.document.blockOf('el-g')?.itemHeight, 0.25);
    _kindSelect(tester).onChanged!('split');
    await tester.pump();
    await _commitField(tester, const ValueKey('block-ratio'), '0.7');
    expect(harness.history.document.blockOf('el-g')?.ratio, 0.7);
    await _commitField(tester, const ValueKey('block-gutter'), '0.02');
    expect(harness.history.document.blockOf('el-g')?.gutter, 0.02);
    _kindSelect(tester).onChanged!('titleBody');
    await tester.pump();
    await _commitField(tester, const ValueKey('block-heightFraction'), '0.3');
    expect(harness.history.document.blockOf('el-g')?.heightFraction, 0.3);
  });
}
