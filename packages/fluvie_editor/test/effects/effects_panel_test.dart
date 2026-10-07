// The Effects tab: add from the browser, toggle, remove, reorder, edit a
// number, and the diamond that keyframes a parameter or collapses it back.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiReorderable, OiThemeData;

Map<String, Object?> _deck({List<Object?>? effects}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '120f',
      'children': [
        {'id': 'el-a', 'type': 'Box', 'effects': ?effects},
        {'id': 'el-b', 'type': 'Box'},
      ],
    },
  ],
};

List<Object?> _effects(EditorDocument document) =>
    document.elementJson('el-a')!['effects']! as List;

Map<String, Object?> _effect(EditorDocument document, int index) =>
    (_effects(document)[index]! as Map).cast<String, Object?>();

final class _Harness {
  _Harness(this.container, this.history);
  final ProviderContainer container;
  final DocumentHistory history;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  List<Object?>? effects,
  Set<String> selection = const {'el-a'},
  double? Function(String id)? playheadProgress,
}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.read(selectionProvider.notifier).select(selection);
  final history = DocumentHistory(EditorDocument.fromJson(_deck(effects: effects)));
  final harness = _Harness(container, history);
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
              width: 300,
              height: 600,
              child: EffectsPanel(
                document: history.document,
                onCommand: history.dispatch,
                playheadProgress: playheadProgress,
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

void main() {
  testWidgets('an empty selection explains the way in', (tester) async {
    await _pump(tester, selection: const {});
    expect(find.text('Select an element to stack effects on it.'), findsOneWidget);
  });

  testWidgets('a multi-selection points at the paste verb', (tester) async {
    await _pump(tester, selection: const {'el-a', 'el-b'});
    expect(find.textContaining('Paste Effects'), findsOneWidget);
  });

  testWidgets('a browser chip adds its effect on the element', (tester) async {
    final harness = await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('effect-chip-grain')));
    await tester.pump();

    expect(_effect(harness.history.document, 0), {'kind': 'grain'});
    harness.history.undo();
    expect(harness.history.document.elementJson('el-a')!.containsKey('effects'), isFalse);
  });

  testWidgets('the search finds an effect the same add lands', (tester) async {
    final harness = await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('effect-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).last, 'vign');
    await tester.pumpAndSettle();
    await tester.tap(find.text('vignette').last);
    await tester.pumpAndSettle();

    expect(_effect(harness.history.document, 0), {'kind': 'vignette'});
  });

  testWidgets('the switch disables and re-enables an effect', (tester) async {
    final harness = await _pump(
      tester,
      effects: [
        {'kind': 'grain', 'amount': 0.3},
      ],
    );

    await tester.tap(find.byKey(const ValueKey('effect-enabled-0')));
    await tester.pump();
    expect(_effect(harness.history.document, 0)['enabled'], false);

    await tester.tap(find.byKey(const ValueKey('effect-enabled-0')));
    await tester.pump();
    expect(_effect(harness.history.document, 0).containsKey('enabled'), isFalse);
  });

  testWidgets('the trash removes the effect as one undo step', (tester) async {
    final harness = await _pump(
      tester,
      effects: [
        {'kind': 'grain'},
        {'kind': 'bloom'},
      ],
    );

    await tester.tap(find.bySemanticsLabel('Remove grain'));
    await tester.pump();

    expect(_effects(harness.history.document), hasLength(1));
    expect(_effect(harness.history.document, 0)['kind'], 'bloom');
    harness.history.undo();
    expect(_effects(harness.history.document), hasLength(2));
  });

  testWidgets('reordering the tiles rewrites the stack order', (tester) async {
    final harness = await _pump(
      tester,
      effects: [
        {'kind': 'grain'},
        {'kind': 'bloom'},
        {'kind': 'vignette'},
      ],
    );

    tester.widget<OiReorderable>(find.byType(OiReorderable)).onReorder(0, 3);
    await tester.pump();

    expect(
      [for (var i = 0; i < 3; i++) _effect(harness.history.document, i)['kind']],
      ['bloom', 'vignette', 'grain'],
    );
  });

  testWidgets('a number edit writes the parameter', (tester) async {
    final harness = await _pump(
      tester,
      effects: [
        {'kind': 'grain', 'amount': 0.3},
      ],
    );

    await tester.enterText(find.byType(EditableText).first, '0.8');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(_effect(harness.history.document, 0)['amount'], 0.8);
  });

  testWidgets('the diamond keyframes a literal into a flat ramp over the window', (tester) async {
    final harness = await _pump(
      tester,
      effects: [
        {'kind': 'grain', 'amount': 0.3},
      ],
    );

    await tester.tap(find.byKey(const ValueKey('effect-stopwatch-0-amount')));
    await tester.pump();

    expect(_effect(harness.history.document, 0)['amount'], {
      'values': [0.3, 0.3],
      'positions': ['0f', '120f'],
    });
    expect(find.byKey(const ValueKey('effect-stops-0-amount')), findsOneWidget);
    harness.history.undo();
    expect(_effect(harness.history.document, 0)['amount'], 0.3);
  });

  testWidgets('the diamond collapses a ramp to the value under the playhead', (tester) async {
    final harness = await _pump(
      tester,
      playheadProgress: (_) => 0.5,
      effects: [
        {
          'kind': 'vignette',
          'amount': {
            'values': [0, 1],
            'positions': ['0f', '120f'],
          },
        },
      ],
    );

    await tester.tap(find.byKey(const ValueKey('effect-stopwatch-0-amount')));
    await tester.pump();

    expect(_effect(harness.history.document, 0)['amount'], closeTo(0.5, 1e-9));
  });

  testWidgets('a boolean flag and an enum write through the same command', (tester) async {
    final harness = await _pump(
      tester,
      effects: [
        {'kind': 'glitch'},
      ],
    );

    await tester.ensureVisible(find.byKey(const ValueKey('effect-flag-0-reverse')));
    await tester.tap(find.byKey(const ValueKey('effect-flag-0-reverse')));
    await tester.pump();
    expect(_effect(harness.history.document, 0)['reverse'], true);
  });
}
