import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'theme': {
    'palette': {'accent': '#6C5CE7', 'background': '#101018'},
  },
  'scenes': [
    {
      'duration': '60f',
      'layout': 'canvas',
      'background': {
        'kind': 'color',
        'color': {'token': 'background'},
      },
      'children': [
        {
          'id': 'el-box',
          'type': 'Box',
          'color': '#22AA55',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.4, 'h': 0.3},
        },
        {
          'id': 'el-bound',
          'type': 'Box',
          'color': {'token': 'accent'},
          'transform': {'x': 0.2, 'y': 0.2, 'w': 0.2, 'h': 0.2},
        },
      ],
    },
  ],
};

final class _Harness {
  _Harness(this.container, this.history);
  final ProviderContainer container;
  final DocumentHistory history;
}

Future<_Harness> _pump(WidgetTester tester, {Set<String> selected = const {}}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final history = DocumentHistory(EditorDocument.fromJson(_deck()));
  container.read(selectionProvider.notifier).select(selected);
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
  return _Harness(container, history);
}

void main() {
  testWidgets('binding a color token from the picker is undoable', (tester) async {
    final harness = await _pump(tester, selected: {'el-box'});
    // Two matches: the property row's label and the field itself.
    await tester.tap(find.bySemanticsLabel('Color').last);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Token accent'));
    await tester.pumpAndSettle();
    expect(harness.history.document.elementJson('el-box')?['color'], {'token': 'accent'});

    harness.history.undo();
    expect(harness.history.document.elementJson('el-box')?['color'], '#22AA55');
  });

  testWidgets('a bound field shows the token chip and unbinds to the literal', (tester) async {
    final harness = await _pump(tester, selected: {'el-bound'});
    expect(find.text('accent'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Unbind Color'));
    await tester.pump();
    expect(harness.history.document.elementJson('el-bound')?['color'], '#FF6C5CE7');

    harness.history.undo();
    expect(harness.history.document.elementJson('el-bound')?['color'], {'token': 'accent'});
  });

  testWidgets('the background color field binds tokens too', (tester) async {
    final harness = await _pump(tester);
    expect(find.text('background'), findsOneWidget, reason: 'the bound chip names its token');

    await tester.tap(find.bySemanticsLabel('Unbind Background color'));
    await tester.pump();
    final background = harness.history.document.sceneJson(0)['background']! as Map<String, Object?>;
    expect(background['color'], '#FF101018');
  });

  testWidgets('a committed literal pick lands in the recents row', (tester) async {
    final harness = await _pump(tester, selected: {'el-box'});
    await tester.tap(find.bySemanticsLabel('Color').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).last, '#FF8800');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    // Escape closes the dialog; the pick commits to the session recents.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(harness.container.read(recentColorsProvider), const [Color(0xFFFF8800)]);
  });
}
