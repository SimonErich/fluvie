// The slide's length as a number. The same edit the boundary hairline makes,
// one gesture apart — and the same refusal when the engine would not have it.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;

Map<String, Object?> _deck({Map<String, Object?>? enter}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': <Object?>[
    {
      'duration': '120f',
      'children': [
        {'id': 'el-a', 'type': 'Text', 'text': 'one'},
      ],
    },
    {
      'duration': '90f',
      'enter': ?enter,
      'children': [
        {'id': 'el-b', 'type': 'Text', 'text': 'two'},
      ],
    },
  ],
};

final class _Harness {
  _Harness(this.history, this.notes);
  final DocumentHistory history;
  final List<String> notes;
}

Future<_Harness> _pump(WidgetTester tester, {int slide = 0, Map<String, Object?>? enter}) async {
  final history = DocumentHistory(EditorDocument.fromJson(_deck(enter: enter)));
  final notes = <String>[];
  await tester.pumpWidget(
    OiApp(
      title: 'test',
      theme: OiThemeData.dark(),
      home: ListenableBuilder(
        listenable: history,
        builder: (context, _) => Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 320,
            child: SlideDurationSection(
              document: history.document,
              slide: slide,
              onCommand: history.dispatch,
              onNote: notes.add,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return _Harness(history, notes);
}

Future<void> _type(WidgetTester tester, int field, String text) async {
  final input = find.byType(EditableText).at(field);
  await tester.tap(input);
  await tester.enterText(input, text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

void main() {
  testWidgets('shows the slide length in frames and in seconds', (tester) async {
    await _pump(tester);

    expect(find.text('120f'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('typing frames retimes the slide', (tester) async {
    final harness = await _pump(tester);

    await _type(tester, 0, '150');

    expect(harness.history.document.sceneJson(0)['duration'], '150f');
  });

  testWidgets('typing seconds writes the same command in frames', (tester) async {
    // Two ways to say one thing: the document only ever holds frames.
    final harness = await _pump(tester);

    await _type(tester, 1, '3');

    expect(harness.history.document.sceneJson(0)['duration'], '90f');
  });

  testWidgets('a duration the engine would refuse is refused, and says why', (tester) async {
    final harness = await _pump(tester, slide: 1, enter: {'kind': 'crossFade', 'duration': '30f'});

    await _type(tester, 0, '20');

    expect(harness.history.document.sceneJson(1)['duration'], '90f', reason: 'nothing written');
    expect(harness.notes.single, contains('cannot fit its transitions'));
  });

  testWidgets('a slide index nothing answers to shows nothing rather than throwing', (
    tester,
  ) async {
    await _pump(tester, slide: 7);

    expect(find.byType(EditableText), findsNothing);
  });
}
