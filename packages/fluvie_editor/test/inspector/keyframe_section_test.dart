import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiSelect, OiThemeData;

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '120f',
      'children': [
        {
          'id': 'el-k',
          'type': 'Box',
          'width': 80,
          'height': 40,
          'animate': [
            {
              'keyframes': [
                {'opacity': 0},
                {'x': 0.5},
                <String, Object?>{},
              ],
              'easings': ['smooth', 'bounce'],
              'duration': '30f',
            },
          ],
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

Future<_Harness> _pump(WidgetTester tester, {int stop = 1}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final history = DocumentHistory(EditorDocument.fromJson(_deck()));
  container.read(selectionProvider.notifier).select({'el-k'});
  container
      .read(keyframeSelectionProvider.notifier)
      .select(SelectedKeyframe(elementId: 'el-k', animation: 0, stop: stop));
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
                child: SingleChildScrollView(
                  child: EditorInspector(
                    document: history.document,
                    slide: 0,
                    onCommand: history.dispatch,
                  ),
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

List<Map<String, Object?>> _stops(EditorDocument document) =>
    (((document.elementJson('el-k')!['animate']! as List).first! as Map)['keyframes']! as List)
        .cast<Map<String, Object?>>();

Map<String, Object?> _animation(EditorDocument document) =>
    ((document.elementJson('el-k')!['animate']! as List).first! as Map).cast<String, Object?>();

/// The keyframe fields follow the Animate panel's length and offset fields:
/// Opacity, X, Y, Scale, ScaleX, ScaleY, Rotation, SkewX, SkewY, Blur.
Finder _field(int index) => find.byType(EditableText).at(2 + index);

Future<void> _commit(WidgetTester tester, Finder field, String text) async {
  await tester.enterText(field, text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

void main() {
  testWidgets('the section shows the selected stop with natural identities', (tester) async {
    await _pump(tester);
    expect(find.text('Keyframe'), findsOneWidget);
    // Opacity is unset on this stop: the field shows the natural 1.
    expect(tester.widget<EditableText>(_field(0)).controller.text, '1');
    // X carries the authored 0.5.
    expect(tester.widget<EditableText>(_field(1)).controller.text, '0.5');
  });

  testWidgets('a numeric edit writes only that field onto the stop', (tester) async {
    final harness = await _pump(tester);
    await _commit(tester, _field(1), '0.8');
    expect(_stops(harness.history.document)[1], {'x': 0.8});
    harness.history.undo();
    expect(_stops(harness.history.document)[1], {'x': 0.5});
  });

  testWidgets('scrub-style repeats on one field coalesce into one undo step', (tester) async {
    final harness = await _pump(tester);
    await _commit(tester, _field(9), '2');
    await _commit(tester, _field(9), '4');
    expect(_stops(harness.history.document)[1], {'x': 0.5, 'blur': 4.0});
    harness.history.undo();
    expect(_stops(harness.history.document)[1], {'x': 0.5});
    expect(harness.history.canUndo, isFalse);
  });

  testWidgets('the color swatch writes the stop color', (tester) async {
    final harness = await _pump(tester);
    await tester.ensureVisible(find.bySemanticsLabel('Keyframe color'));
    await tester.tap(find.bySemanticsLabel('Keyframe color'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).last, '#FF0000');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(_stops(harness.history.document)[1]['color'], '#FFFF0000');
  });

  testWidgets('the origin select writes the named alignment', (tester) async {
    final harness = await _pump(tester);
    tester.widget<OiSelect<String>>(find.byKey(const ValueKey('kf-origin'))).onChanged!('topLeft');
    await tester.pump();
    expect(_stops(harness.history.document)[1]['origin'], 'topLeft');
  });

  testWidgets('the outgoing easing edits per segment', (tester) async {
    final harness = await _pump(tester);
    tester.widget<OiSelect<String>>(find.byKey(const ValueKey('kf-easing'))).onChanged!('elastic');
    await tester.pump();
    expect(_animation(harness.history.document)['easings'], ['smooth', 'elastic']);
  });

  testWidgets('the last stop has no outgoing easing row', (tester) async {
    await _pump(tester, stop: 2);
    expect(find.text('Keyframe'), findsOneWidget);
    expect(find.byKey(const ValueKey('kf-easing')), findsNothing);
  });

  testWidgets('a stale selection renders no section', (tester) async {
    await _pump(tester, stop: 9);
    expect(find.text('Keyframe'), findsNothing);
  });
}
