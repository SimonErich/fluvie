import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiSelect, OiThemeData;

/// Two elements: el-a (optionally anchored) and el-b, whose first animation
/// the Animate panel edits.
Map<String, Object?> _deck({String? aAnchor, Object? bAt, String? bDelay}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '120f',
      'children': [
        {
          'id': 'el-a',
          'type': 'Box',
          'width': 80,
          'height': 40,
          'anchor': ?aAnchor,
          'animate': [
            {'preset': 'fadeIn', 'duration': '30f'},
          ],
        },
        {
          'id': 'el-b',
          'type': 'Text',
          'text': 'hello',
          'animate': [
            {
              'preset': 'fadeIn',
              'duration': '30f',
              'at': ?bAt,
              'delay': ?bDelay,
            },
          ],
        },
      ],
    },
  ],
};

Future<DocumentHistory> _pump(WidgetTester tester, Map<String, Object?> deck) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final history = DocumentHistory(EditorDocument.fromJson(deck));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: OiApp(
        title: 'test',
        theme: OiThemeData.dark(),
        home: ListenableBuilder(
          listenable: history,
          builder: (context, _) => Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 280,
              child: SingleChildScrollView(
                child: AnimateSection(
                  document: history.document,
                  slide: 0,
                  elementId: 'el-b',
                  onCommand: history.dispatch,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return history;
}

Map<String, Object?> _animation(EditorDocument document) =>
    ((document.elementJson('el-b')!['animate']! as List).first! as Map).cast<String, Object?>();

OiSelect<String> _trigger(WidgetTester tester) =>
    tester.widget<OiSelect<String>>(find.byKey(const ValueKey('animate-trigger-0')));

void main() {
  testWidgets('the trigger select offers every other element as a target', (tester) async {
    await _pump(tester, _deck());
    final options = _trigger(tester).options;
    expect(
      options.map((option) => option.value),
      containsAll(['auto', 'previous', 'whenEnds:el-a', 'whenStarts:el-a']),
    );
    // The element itself is never a target.
    expect(options.map((option) => option.value), isNot(contains('whenEnds:el-b')));
    final labels = {for (final option in options) option.value: option.label};
    expect(labels['whenEnds:el-a'], 'when Box ends');
    expect(labels['whenStarts:el-a'], 'when Box starts');
  });

  testWidgets('choosing a target writes whenEnds and mints the anchor', (tester) async {
    final history = await _pump(tester, _deck());
    _trigger(tester).onChanged!('whenEnds:el-a');
    await tester.pump();
    expect(_animation(history.document)['at'], {'kind': 'whenEnds', 'anchor': 'el-a'});
    expect(history.document.elementJson('el-a')!['anchor'], 'el-a');
    history.undo();
    expect(_animation(history.document).containsKey('at'), isFalse);
    expect(history.document.elementJson('el-a')!.containsKey('anchor'), isFalse);
  });

  testWidgets('an authored anchor trigger reads back as its target form', (tester) async {
    final history = await _pump(
      tester,
      _deck(aAnchor: 'hero', bAt: {'kind': 'whenEnds', 'anchor': 'hero'}),
    );
    expect(_trigger(tester).value, 'whenEnds:el-a');
    // Switching to the starts form reuses the declared anchor id.
    _trigger(tester).onChanged!('whenStarts:el-a');
    await tester.pump();
    expect(_animation(history.document)['at'], {'kind': 'whenStarts', 'anchor': 'hero'});
  });

  testWidgets('a trigger anchored on another slide stays custom', (tester) async {
    final deck = _deck(bAt: {'kind': 'whenEnds', 'anchor': 'elsewhere'});
    (deck['scenes']! as List).add({
      'duration': '60f',
      'children': [
        {'id': 'el-c', 'type': 'Box', 'width': 10, 'height': 10, 'anchor': 'elsewhere'},
      ],
    });
    await _pump(tester, deck);
    final select = _trigger(tester);
    expect(select.value, 'custom');
    final custom = select.options.firstWhere((option) => option.value == 'custom');
    expect(custom.enabled, isFalse);
  });

  testWidgets('beat and absolute triggers stay custom too', (tester) async {
    await _pump(
      tester,
      _deck(
        bAt: {'kind': 'at', 'time': '1s'},
      ),
    );
    expect(_trigger(tester).value, 'custom');
  });

  testWidgets('the offset field shows the delay and writes it back', (tester) async {
    final history = await _pump(tester, _deck(bDelay: '12f'));
    // Fields: Length (index 0), Offset (index 1).
    final offset = find.byType(EditableText).at(1);
    expect(tester.widget<EditableText>(offset).controller.text, '12');
    await tester.enterText(offset, '20');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(_animation(history.document)['delay'], '20f');
    history.undo();
    expect(_animation(history.document)['delay'], '12f');
  });

  testWidgets('a zero offset clears the delay key', (tester) async {
    final history = await _pump(tester, _deck(bDelay: '12f'));
    await tester.enterText(find.byType(EditableText).at(1), '0');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(_animation(history.document).containsKey('delay'), isFalse);
  });
}
