import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart';

void main() {
  testWidgets('motion edits each animation and effect segment then undoes independently', (
    tester,
  ) async {
    final history = DocumentHistory(
      EditorDocument.fromJson(const {
        'fluvieSpec': 1,
        'scenes': [
          {
            'duration': '60f',
            'children': [
              {
                'id': 'a',
                'type': 'Box',
                'animate': [
                  {
                    'duration': '60f',
                    'keyframes': [
                      {'opacity': 0},
                      {'opacity': .5},
                      {'opacity': 1},
                    ],
                    'easings': ['smooth', 'linear'],
                  },
                ],
                'effects': [
                  {
                    'kind': 'grain',
                    'amount': {
                      'values': [0, .4, 1],
                      'positions': ['0r', '.5r', '1r'],
                    },
                  },
                  {
                    'kind': 'blur',
                    'sigma': {
                      'values': [0, 2],
                      'positions': ['0r', '1r'],
                      'easings': ['smooth'],
                    },
                  },
                ],
              },
            ],
          },
        ],
      }),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    addTearDown(history.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: OiApp(
          home: ListenableBuilder(
            listenable: history,
            builder: (_, _) =>
                AnimationPanel(document: history.document, onCommand: history.dispatch),
          ),
        ),
      ),
    );
    expect(find.text('Select one element to edit motion.'), findsOneWidget);
    container.read(selectionProvider.notifier).select({'a'});
    await tester.pumpAndSettle();
    final baseline = history.document.renderDigest;
    final editors = tester.widgetList<EasingCurveEditor>(find.byType(EasingCurveEditor)).toList();
    expect(editors, hasLength(6));
    for (var i = 0; i < editors.length; i++) {
      final editor = tester
          .widgetList<EasingCurveEditor>(find.byType(EasingCurveEditor))
          .elementAt(i);
      editor.onChanged(
        i.isEven
            ? 'bounce'
            : {
                'cubic': [.1, .3, .7, .9],
              },
      );
      await tester.pumpAndSettle();
      expect(history.document.renderDigest, isNot(baseline));
      final rebuilt = EditorDocument.fromJson(history.document.toJson());
      expect(rebuilt.spec.build(), isNotNull);
      history.undo();
      await tester.pumpAndSettle();
      expect(history.document.renderDigest, baseline);
    }
    final first = find.byType(EasingCurveEditor).first;
    tester
        .widget<OiSelect<String>>(
          find.descendant(of: first, matching: find.byType(OiSelect<String>)),
        )
        .onChanged!('elastic');
    await tester.pumpAndSettle();
    expect(tester.widget<EasingCurveEditor>(first).value, 'elastic');
    tester
        .widget<MathNumberInput>(
          find.descendant(of: first, matching: find.byKey(const ValueKey('easing-control-0'))),
        )
        .onChanged(.3);
    await tester.pumpAndSettle();
    expect(tester.widget<EasingCurveEditor>(first).value, {
      'cubic': [.3, 0.0, 1.0, 1.0],
    });
    expect(tester.takeException(), isNull);
  });
}
