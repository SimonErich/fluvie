import 'package:flutter/services.dart';
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
      'children': [
        {
          'id': 'el-a',
          'type': 'Box',
          'color': '#6C5CE7',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.2, 'h': 0.2},
        },
      ],
    },
  ],
};

final class _Harness {
  _Harness(this.history);
  final DocumentHistory history;
  final List<Set<String>> travelled = [];
}

/// Pumps an interactive canvas whose [historyActionsProvider] is backed by
/// a real [DocumentHistory] — the slides app's wiring in miniature.
Future<_Harness> _pump(WidgetTester tester) async {
  final history = DocumentHistory(EditorDocument.fromJson(_deck()));
  final harness = _Harness(history);
  final container = ProviderContainer(
    overrides: [
      historyActionsProvider.overrideWithValue(
        HistoryActions(
          canUndo: () => history.canUndo,
          canRedo: () => history.canRedo,
          undo: () => harness.travelled.add(history.undo()),
          redo: () => harness.travelled.add(history.redo()),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
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
  return harness;
}

Future<void> _chord(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool shift = false,
}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

void main() {
  testWidgets('Ctrl+Z with canvas focus undoes through the provider', (tester) async {
    final harness = await _pump(tester);
    harness.history.dispatch(
      const SetTransformCommand(id: 'el-a', transform: {'x': 0.1, 'y': 0.1, 'w': 0.2, 'h': 0.2}),
    );
    await tester.pump();
    await _chord(tester, LogicalKeyboardKey.keyZ);
    final transform = harness.history.document.elementJson('el-a')!['transform']! as Map;
    expect(transform['x'], 0.5);
    expect(harness.travelled, [
      {'el-a'},
    ]);
  });

  testWidgets('Ctrl+Shift+Z and Ctrl+Y redo through the provider', (tester) async {
    final harness = await _pump(tester);
    harness.history.dispatch(
      const SetTransformCommand(id: 'el-a', transform: {'x': 0.1, 'y': 0.1, 'w': 0.2, 'h': 0.2}),
    );
    await tester.pump();
    await _chord(tester, LogicalKeyboardKey.keyZ);
    await _chord(tester, LogicalKeyboardKey.keyZ, shift: true);
    Map<String, Object?> transform() =>
        (harness.history.document.elementJson('el-a')!['transform']! as Map)
            .cast<String, Object?>();
    expect(transform()['x'], 0.1);
    await _chord(tester, LogicalKeyboardKey.keyZ);
    expect(transform()['x'], 0.5);
    await _chord(tester, LogicalKeyboardKey.keyY);
    expect(transform()['x'], 0.1);
  });

  testWidgets('an empty history leaves the chord inert', (tester) async {
    final harness = await _pump(tester);
    await _chord(tester, LogicalKeyboardKey.keyZ);
    expect(harness.travelled, isEmpty);
    expect(harness.history.canUndo, isFalse);
  });
}
