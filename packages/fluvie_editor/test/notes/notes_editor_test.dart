import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': <Object?>[
    <String, Object?>{
      'duration': '60f',
      'children': [
        {'id': 'el-a', 'type': 'Text', 'text': 'a'},
      ],
    },
    <String, Object?>{
      'duration': '120f',
      'children': [
        {'id': 'el-b1', 'type': 'Text', 'text': 'first'},
        {'id': 'el-b2', 'type': 'Text', 'text': 'second'},
      ],
      'steps': [
        {
          'elements': ['el-b2'],
        },
      ],
    },
  ],
};

Future<DocumentHistory> _pump(WidgetTester tester, {int slide = 0}) async {
  final history = DocumentHistory(EditorDocument.fromJson(_deck()));
  await tester.pumpWidget(
    OiApp(
      title: 'test',
      theme: OiThemeData.dark(),
      home: ListenableBuilder(
        listenable: history,
        builder: (context, _) => Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 640,
            child: NotesEditor(
              document: history.document,
              slide: slide,
              onCommand: history.dispatch,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return history;
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Show the notes editor'));
  await tester.pump();
}

Finder _fieldIn(Key key) =>
    find.descendant(of: find.byKey(key), matching: find.byType(EditableText));

Future<void> _type(WidgetTester tester, Key key, String text) async {
  await tester.enterText(_fieldIn(key), text);
  await tester.pump();
  tester.widget<EditableText>(_fieldIn(key)).focusNode.unfocus();
  // The focus loss commits in a microtask; the second pump rebuilds the
  // strip from the changed document before the next gesture.
  await tester.pump();
  await tester.pump();
}

Map<String, Object?>? _sceneNotes(DocumentHistory history, int slide) =>
    history.document.sceneJson(slide)['notes'] as Map<String, Object?>?;

List<Map<String, Object?>> _steps(DocumentHistory history, int slide) => [
  ...(history.document.sceneJson(slide)['steps']! as List).whereType<Map<String, Object?>>(),
];

void main() {
  testWidgets('starts closed and opens from the header', (tester) async {
    await _pump(tester);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Highlights'), findsNothing);
    await _open(tester);
    expect(find.text('Highlights'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Collapse the notes editor'));
    await tester.pump();
    expect(find.text('Highlights'), findsNothing);
  });

  testWidgets('typing into the empty prose field creates the scene notes', (tester) async {
    final history = await _pump(tester);
    await _open(tester);
    expect(find.text('Type what the speaker should say'), findsOneWidget);
    await _type(tester, const ValueKey('note-text'), 'Open with the story.');
    expect(_sceneNotes(history, 0), {'text': 'Open with the story.'});
  });

  testWidgets('a step-less slide offers no scope chips', (tester) async {
    await _pump(tester);
    await _open(tester);
    expect(find.text('Slide'), findsNothing);
    expect(find.text('Step 1'), findsNothing);
  });

  testWidgets('the step scope edits the step override', (tester) async {
    final history = await _pump(tester, slide: 1);
    await _open(tester);
    expect(find.text('Slide'), findsOneWidget);
    await tester.tap(find.text('Step 1'));
    await tester.pump();
    expect(find.text('Replace the slide text for this step'), findsOneWidget);
    await _type(tester, const ValueKey('note-text'), 'Land the punchline.');
    expect(_steps(history, 1), [
      {
        'elements': ['el-b2'],
        'notes': {'text': 'Land the punchline.'},
      },
    ]);
    // The slide scope stayed untouched.
    expect(_sceneNotes(history, 1), isNull);
  });

  testWidgets('highlights add, edit, reorder, and remove through commands', (tester) async {
    final history = await _pump(tester);
    history.dispatch(
      const SetSceneNotesCommand(
        index: 0,
        notes: {
          'text': 'say',
          'highlights': ['one', 'two'],
        },
      ),
    );
    await tester.pump();
    await _open(tester);

    await _type(tester, const ValueKey('note-add-highlight'), 'three');
    expect(_sceneNotes(history, 0)!['highlights'], ['one', 'two', 'three']);

    await _type(tester, const ValueKey('note-highlight-1'), 'two edited');
    expect(_sceneNotes(history, 0)!['highlights'], ['one', 'two edited', 'three']);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('note-highlight-2')),
        matching: find.bySemanticsLabel('Move the highlight up'),
      ),
    );
    await tester.pump();
    expect(_sceneNotes(history, 0)!['highlights'], ['one', 'three', 'two edited']);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('note-highlight-0')),
        matching: find.bySemanticsLabel('Move the highlight down'),
      ),
    );
    await tester.pump();
    expect(_sceneNotes(history, 0)!['highlights'], ['three', 'one', 'two edited']);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('note-highlight-0')),
        matching: find.bySemanticsLabel('Remove the highlight'),
      ),
    );
    await tester.pump();
    expect(_sceneNotes(history, 0)!['highlights'], ['one', 'two edited']);

    // Clearing a bullet's text removes the bullet itself.
    await _type(tester, const ValueKey('note-highlight-0'), '');
    expect(_sceneNotes(history, 0)!['highlights'], ['two edited']);
  });

  testWidgets('clearing every field removes the notes key entirely', (tester) async {
    final history = await _pump(tester);
    history.dispatch(
      const SetSceneNotesCommand(
        index: 0,
        notes: {
          'text': 'say',
          'highlights': ['a'],
        },
      ),
    );
    await tester.pump();
    await _open(tester);
    await _type(tester, const ValueKey('note-text'), '');
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('note-highlight-0')),
        matching: find.bySemanticsLabel('Remove the highlight'),
      ),
    );
    await tester.pump();
    expect(history.document.sceneJson(0).containsKey('notes'), isFalse);
  });

  testWidgets('the merge preview shows what the speaker sees for the scope', (tester) async {
    final history = await _pump(tester, slide: 1);
    history
      ..dispatch(
        const SetSceneNotesCommand(
          index: 1,
          notes: {
            'text': 'scene default',
            'highlights': ['always'],
          },
        ),
      )
      ..dispatch(
        const SetStepNotesCommand(
          index: 1,
          step: 0,
          notes: {
            'text': 'step story',
            'highlights': ['now'],
          },
        ),
      );
    await tester.pump();
    await _open(tester);
    expect(find.textContaining('Speaker sees: scene default — always'), findsOneWidget);
    await tester.tap(find.text('Step 1'));
    await tester.pump();
    expect(find.textContaining('Speaker sees: step story — always · now'), findsOneWidget);
  });

  testWidgets('losing the steps falls back to the slide scope', (tester) async {
    final history = await _pump(tester, slide: 1);
    await _open(tester);
    await tester.tap(find.text('Step 1'));
    await tester.pump();
    history.dispatch(const SetSceneStepsCommand(index: 1, steps: null));
    await tester.pump();
    expect(find.text('Step 1'), findsNothing);
    expect(find.text('Type what the speaker should say'), findsOneWidget);
  });
}
