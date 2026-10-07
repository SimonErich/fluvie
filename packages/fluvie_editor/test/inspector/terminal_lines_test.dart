import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:fluvie_editor/src/inspector/terminal_lines_section.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiSelect, OiThemeData;

const Map<String, Object?> _terminal = {
  'type': 'Terminal',
  'lines': [
    {'cmd': 'ls -la'},
    {'out': 'total 2'},
    {'cmd': 'pwd', 'prompt': '# '},
  ],
};

Future<List<Map<String, Object?>>> _pump(
  WidgetTester tester, [
  Map<String, Object?> element = _terminal,
]) async {
  final patches = <Map<String, Object?>>[];
  await tester.pumpWidget(
    OiApp(
      title: 'test',
      theme: OiThemeData.dark(),
      home: Center(
        child: SizedBox(
          width: 280,
          child: SingleChildScrollView(
            child: TerminalLinesSection(
              element: element,
              patch: (patch, {mergeGroup}) => patches.add(patch),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return patches;
}

Future<void> _commit(WidgetTester tester, Finder field, String text) async {
  await tester.enterText(field, text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

void main() {
  testWidgets('shows a kind select per row and a prompt field on cmd rows only', (tester) async {
    await _pump(tester);
    expect(find.byType(OiSelect<String>), findsNWidgets(3));
    // Two cmd rows carry text + prompt, the out row text only.
    expect(find.byType(EditableText), findsNWidgets(5));
  });

  testWidgets('edits a row text in place', (tester) async {
    final patches = await _pump(tester);
    await _commit(tester, find.byKey(const ValueKey('line-text-1')), 'total 4');
    expect(patches.single, {
      'lines': [
        {'cmd': 'ls -la'},
        {'out': 'total 4'},
        {'cmd': 'pwd', 'prompt': '# '},
      ],
    });
  });

  testWidgets('switching a cmd row to out drops its prompt', (tester) async {
    final patches = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('line-kind-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('out').last);
    await tester.pumpAndSettle();
    expect(patches.single, {
      'lines': [
        {'cmd': 'ls -la'},
        {'out': 'total 2'},
        {'out': 'pwd'},
      ],
    });
  });

  testWidgets('switching an out row to cmd keeps its text', (tester) async {
    final patches = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('line-kind-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('cmd').last);
    await tester.pumpAndSettle();
    expect(patches.single, {
      'lines': [
        {'cmd': 'ls -la'},
        {'cmd': 'total 2'},
        {'cmd': 'pwd', 'prompt': '# '},
      ],
    });
  });

  testWidgets('edits the per-line prompt; empty removes it', (tester) async {
    final patches = await _pump(tester);
    await _commit(tester, find.byKey(const ValueKey('line-prompt-0')), '>>> ');
    expect(patches.single, {
      'lines': [
        {'cmd': 'ls -la', 'prompt': '>>> '},
        {'out': 'total 2'},
        {'cmd': 'pwd', 'prompt': '# '},
      ],
    });
    await _commit(tester, find.byKey(const ValueKey('line-prompt-2')), '');
    expect(patches.last, {
      'lines': [
        {'cmd': 'ls -la'},
        {'out': 'total 2'},
        {'cmd': 'pwd'},
      ],
    });
  });

  testWidgets('adds a line, removes one, but never the last', (tester) async {
    final patches = await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Add line'));
    await tester.pump();
    expect(patches.single['lines']! as List, hasLength(4));
    expect((patches.single['lines']! as List).last, {'cmd': ''});

    await tester.tap(find.bySemanticsLabel('Remove line 1'));
    await tester.pump();
    expect(patches.last, {
      'lines': [
        {'cmd': 'ls -la'},
        {'cmd': 'pwd', 'prompt': '# '},
      ],
    });

    final lastOne = await _pump(tester, const {
      'type': 'Terminal',
      'lines': [
        {'cmd': 'ls'},
      ],
    });
    await tester.tap(find.bySemanticsLabel('Remove line 0'));
    await tester.pump();
    expect(lastOne, isEmpty);
  });

  testWidgets('reorders adjacent lines within bounds', (tester) async {
    final patches = await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Move line 1 up'));
    await tester.pump();
    expect(patches.single, {
      'lines': [
        {'out': 'total 2'},
        {'cmd': 'ls -la'},
        {'cmd': 'pwd', 'prompt': '# '},
      ],
    });
    await tester.tap(find.bySemanticsLabel('Move line 0 up'));
    await tester.tap(find.bySemanticsLabel('Move line 2 down'));
    await tester.pump();
    expect(patches, hasLength(1), reason: 'the edges cannot move outward');
  });

  group('through the inspector', () {
    testWidgets('the Lines section edits the document undoably', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final history = DocumentHistory(
        EditorDocument.fromJson(const {
          'fluvieSpec': 1,
          'size': {'width': 320, 'height': 180},
          'fps': 30,
          'scenes': [
            {
              'duration': '60f',
              'children': [
                {
                  'id': 'el-term',
                  ..._terminal,
                  'transform': {'x': 0.5, 'y': 0.5, 'w': 0.6, 'h': 0.6},
                },
              ],
            },
          ],
        }),
      );
      container.read(selectionProvider.notifier).select({'el-term'});
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
                      onCommand: history.dispatch,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Lines'), findsOneWidget);
      await _commit(tester, find.byKey(const ValueKey('line-text-0')), 'ls');
      final lines = history.document.elementJson('el-term')!['lines']! as List;
      expect(lines.first, {'cmd': 'ls'});
      history.undo();
      expect(
        (history.document.elementJson('el-term')!['lines']! as List).first,
        {'cmd': 'ls -la'},
      );
    });
  });
}
