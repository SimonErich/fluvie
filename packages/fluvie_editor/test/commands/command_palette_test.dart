import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiCommandBar, OiThemeData;

import 'fake_system_clipboard.dart';

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
          'color': '#E17055',
          'transform': {'x': 0.2, 'y': 0.4, 'w': 0.2, 'h': 0.2},
        },
        {
          'id': 'el-b',
          'type': 'Box',
          'color': '#0984E3',
          'transform': {'x': 0.6, 'y': 0.5, 'w': 0.2, 'h': 0.2},
        },
      ],
    },
    {'duration': '60f', 'children': <Object?>[]},
  ],
};

final class _Harness {
  _Harness(this.history);

  final DocumentHistory history;
  Set<String> selection = {'el-a'};
  int shownSlide = -1;

  CommandScope scope() => CommandScope(
    document: history.document,
    slide: 0,
    selection: selection,
    clipboard: EditorClipboard(),
    dispatch: history.dispatch,
    select: (ids) => selection = ids,
    showSlide: (slide) => shownSlide = slide,
  );
}

Future<_Harness> _pump(WidgetTester tester) async {
  final harness = _Harness(DocumentHistory(EditorDocument.fromJson(_deck())));
  await tester.pumpWidget(
    OiApp(
      title: 'test',
      theme: OiThemeData.dark(),
      home: EditorCommandPalette(
        scopeBuilder: harness.scope,
        child: const Focus(autofocus: true, child: SizedBox.expand()),
      ),
    ),
  );
  await tester.pump();
  return harness;
}

Future<void> _openPalette(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

void main() {
  final fake = FakeSystemClipboard();
  setUp(fake.install);
  tearDown(() {
    fake
      ..text = null
      ..uninstall();
  });

  testWidgets('Ctrl+K opens the palette; Escape closes it', (tester) async {
    await _pump(tester);
    expect(find.byType(OiCommandBar), findsNothing);
    await _openPalette(tester);
    expect(find.byType(OiCommandBar), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byType(OiCommandBar), findsNothing);
  });

  testWidgets('every enabled command is listed', (tester) async {
    await _pump(tester);
    await _openPalette(tester);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Duplicate'), findsOneWidget);
    expect(find.text('Add slide'), findsOneWidget);
  });

  testWidgets('search narrows the list', (tester) async {
    await _pump(tester);
    await _openPalette(tester);
    await tester.enterText(find.byType(EditableText), 'duplicate slide');
    await tester.pump();
    expect(find.text('Duplicate slide'), findsOneWidget);
    expect(find.text('Copy'), findsNothing);
  });

  testWidgets('executing runs against the scope and closes the palette', (tester) async {
    final harness = await _pump(tester);
    await _openPalette(tester);
    await tester.enterText(find.byType(EditableText), 'duplicate slide');
    await tester.pump();
    await tester.tap(find.text('Duplicate slide'));
    await tester.pump();
    expect(harness.history.document.sceneCount, 3);
    expect(harness.shownSlide, 1);
    expect(find.byType(OiCommandBar), findsNothing);
  });

  testWidgets('a disabled command stays out of the list', (tester) async {
    final harness = await _pump(tester);
    harness.selection = const {};
    await _openPalette(tester);
    expect(find.text('Copy'), findsNothing);
    expect(find.text('Paste'), findsOneWidget);
  });

  testWidgets('recents float to the top on the next open', (tester) async {
    await _pump(tester);
    await _openPalette(tester);
    await tester.enterText(find.byType(EditableText), 'add slide');
    await tester.pump();
    await tester.tap(find.text('Add slide'));
    await tester.pump();
    await _openPalette(tester);
    // The first listed tile is the command just executed.
    final firstTile = tester.getTopLeft(find.text('Add slide'));
    for (final label in ['Copy', 'Duplicate', 'Paste']) {
      expect(firstTile.dy, lessThan(tester.getTopLeft(find.text(label)).dy));
    }
  });
}
