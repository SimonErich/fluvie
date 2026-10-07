import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiSelect, OiThemeData;

Map<String, Object?> _deck({bool themed = true}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  if (themed)
    'theme': {
      'palette': {'accent': '#6C5CE7', 'unused': '#123456'},
      'typeScale': {
        'title': {'fontSize': 48, 'fontWeight': 'w700'},
      },
      'spacing': {'m': 24.0},
      'motion': {'duration': '300ms', 'ease': 'out'},
    },
  'scenes': [
    {
      'duration': '60f',
      'layout': 'canvas',
      'children': [
        {
          'id': 'el-box',
          'type': 'Box',
          'color': {'token': 'accent'},
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.4, 'h': 0.3},
        },
      ],
    },
  ],
};

Future<DocumentHistory> _pump(WidgetTester tester, {bool themed = true}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final history = DocumentHistory(EditorDocument.fromJson(_deck(themed: themed)));
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
              SizedBox(
                width: 220,
                child: ThemePanel(document: history.document, onCommand: history.dispatch),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return history;
}

Map<String, Object?> _themeOf(DocumentHistory history) => history.document.themeJson!;

void main() {
  testWidgets('start from applies a builtin theme as one undo step', (tester) async {
    final history = await _pump(tester, themed: false);
    await tester.tap(find.text('midnight'));
    await tester.pump();
    expect(_themeOf(history), builtinThemes['midnight']);
    expect(history.undoLabel, 'Apply theme');
    history.undo();
    expect(history.document.themeJson, isNull);
  });

  testWidgets('a themeless deck still offers the starters', (tester) async {
    await _pump(tester, themed: false);
    expect(find.text('midnight'), findsOneWidget);
    expect(find.text('paper'), findsOneWidget);
    expect(find.text('neon'), findsOneWidget);
  });

  testWidgets('palette color edits coalesce into one undoable step', (tester) async {
    final history = await _pump(tester);
    await tester.tap(find.bySemanticsLabel('accent color'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).last, '#FF0000');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.enterText(find.byType(EditableText).last, '#00FF00');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect((_themeOf(history)['palette']! as Map)['accent'], '#FF00FF00');
    expect(history.undoLabel, 'Edit theme');
    history.undo();
    expect((_themeOf(history)['palette']! as Map)['accent'], '#6C5CE7');
  });

  testWidgets('add color mints a unique token name', (tester) async {
    final history = await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Add color'));
    await tester.pump();
    expect((_themeOf(history)['palette']! as Map).containsKey('color1'), isTrue);
  });

  testWidgets('renaming a token rewrites its references undoably', (tester) async {
    final history = await _pump(tester);
    await tester.enterText(find.bySemanticsLabel('Rename accent'), 'brand');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect((_themeOf(history)['palette']! as Map).containsKey('brand'), isTrue);
    expect(history.document.elementJson('el-box')?['color'], {'token': 'brand'});
    history.undo();
    expect(history.document.elementJson('el-box')?['color'], {'token': 'accent'});
  });

  testWidgets('a rename to a taken or invalid name is refused', (tester) async {
    final history = await _pump(tester);
    await tester.enterText(find.bySemanticsLabel('Rename accent'), 'unused');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.enterText(find.bySemanticsLabel('Rename accent'), '1bad name');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect((_themeOf(history)['palette']! as Map).keys, contains('accent'));
    expect(history.canUndo, isFalse);
  });

  testWidgets('remove is blocked for a referenced token, open for the rest', (tester) async {
    final history = await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Remove accent'));
    await tester.pump();
    expect((_themeOf(history)['palette']! as Map).containsKey('accent'), isTrue);

    await tester.tap(find.bySemanticsLabel('Remove unused'));
    await tester.pump();
    expect((_themeOf(history)['palette']! as Map).containsKey('unused'), isFalse);
    history.undo();
    expect((_themeOf(history)['palette']! as Map).containsKey('unused'), isTrue);
  });

  testWidgets('the type scale edits size, weight, and family', (tester) async {
    final history = await _pump(tester);
    await tester.enterText(find.bySemanticsLabel('title size'), '64');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(((_themeOf(history)['typeScale']! as Map)['title']! as Map)['fontSize'], 64.0);

    tester.widget<OiSelect<String>>(find.byKey(const ValueKey('theme-weight-title'))).onChanged!(
      'w400',
    );
    await tester.pump();
    expect(((_themeOf(history)['typeScale']! as Map)['title']! as Map)['fontWeight'], 'w400');

    await tester.enterText(find.bySemanticsLabel('title family'), 'Inter');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(((_themeOf(history)['typeScale']! as Map)['title']! as Map)['fontFamily'], 'Inter');
  });

  testWidgets('spacing edits its number', (tester) async {
    final history = await _pump(tester);
    await tester.enterText(find.bySemanticsLabel('m spacing'), '32');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect((_themeOf(history)['spacing']! as Map)['m'], 32.0);
  });

  testWidgets('motion edits the duration and ease; bad durations revert', (tester) async {
    final history = await _pump(tester);
    await tester.enterText(find.bySemanticsLabel('Motion duration'), '500ms');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect((_themeOf(history)['motion']! as Map)['duration'], '500ms');

    await tester.enterText(find.bySemanticsLabel('Motion duration'), 'not a time');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect((_themeOf(history)['motion']! as Map)['duration'], '500ms');

    tester.widget<OiSelect<String>>(find.byKey(const ValueKey('theme-motion-ease'))).onChanged!(
      'snappy',
    );
    await tester.pump();
    expect((_themeOf(history)['motion']! as Map)['ease'], 'snappy');
  });
}
