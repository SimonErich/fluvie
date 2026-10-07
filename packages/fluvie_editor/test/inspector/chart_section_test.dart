import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:fluvie_editor/src/inspector/chart_data_section.dart';
import 'package:fluvie_editor/src/inspector/inspector_sections.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiPropertyGrid, OiSelect, OiThemeData;

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  OiApp(
    title: 'test',
    theme: OiThemeData.dark(),
    home: Center(
      child: SizedBox(width: 280, child: SingleChildScrollView(child: child)),
    ),
  ),
);

Future<List<Map<String, Object?>>> _rowsFor(
  WidgetTester tester,
  Map<String, Object?> element,
) async {
  final patches = <Map<String, Object?>>[];
  await _pump(
    tester,
    OiPropertyGrid(
      properties: styleRowsFor(element, (patch, {mergeGroup}) => patches.add(patch)),
    ),
  );
  return patches;
}

Future<List<Map<String, Object?>>> _gridFor(
  WidgetTester tester,
  Map<String, Object?> element,
) async {
  final patches = <Map<String, Object?>>[];
  await _pump(
    tester,
    ChartDataSection(element: element, patch: (patch, {mergeGroup}) => patches.add(patch)),
  );
  return patches;
}

Future<void> _commitField(WidgetTester tester, int index, String text) async {
  await tester.enterText(find.byType(EditableText).at(index), text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

const Map<String, Object?> _barChart = {
  'type': 'Chart',
  'variant': 'bar',
  'data': {'A': 3, 'B': 5, 'C': 2},
};

void main() {
  group('chart style rows', () {
    testWidgets('the variant select switches within the data form', (tester) async {
      final patches = await _rowsFor(tester, _barChart);
      await tester.tap(find.byKey(const ValueKey('style-variant')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('donut').last);
      await tester.pumpAndSettle();
      expect(patches.single, {'variant': 'donut'});
    });

    testWidgets('leaving donut scrubs the inner radius', (tester) async {
      final patches = await _rowsFor(tester, const {
        'type': 'Chart',
        'variant': 'donut',
        'data': {'A': 3},
        'innerRadius': 0.4,
      });
      await tester.tap(find.byKey(const ValueKey('style-variant')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('pie').last);
      await tester.pumpAndSettle();
      expect(patches.single, {'variant': 'pie', 'innerRadius': null});
    });

    testWidgets('a donut edits its inner radius', (tester) async {
      final patches = await _rowsFor(tester, const {
        'type': 'Chart',
        'variant': 'donut',
        'data': {'A': 3},
      });
      // Fields: reveal, then inner radius.
      await _commitField(tester, 1, '0.4');
      expect(patches.single, {'innerRadius': 0.4});
    });

    testWidgets('the reveal edits as a spec time and invalid input drops', (tester) async {
      final patches = await _rowsFor(tester, _barChart);
      await _commitField(tester, 0, '1s');
      expect(patches.single, {'reveal': '1s'});
      await _commitField(tester, 0, 'nope');
      expect(patches, hasLength(1));
    });

    testWidgets('a series chart restricts the variant select to the legal family', (tester) async {
      // Two series: line and area only (scatter takes a single series).
      final patches = await _rowsFor(tester, const {
        'type': 'Chart',
        'variant': 'line',
        'series': [
          {
            'name': 'a',
            'data': {'x': 1},
          },
          {
            'name': 'b',
            'data': {'x': 2},
          },
        ],
      });
      final select = tester.widget<OiSelect<String>>(find.byKey(const ValueKey('style-variant')));
      expect(select.enabled, isTrue);
      expect([for (final option in select.options) option.value], ['line', 'area']);
      await tester.tap(find.byKey(const ValueKey('style-variant')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('area').last);
      await tester.pumpAndSettle();
      expect(patches.single, {'variant': 'area', 'innerRadius': null});
    });

    testWidgets('a single series adds scatter; a points chart stays scatter-only', (tester) async {
      await _rowsFor(tester, const {
        'type': 'Chart',
        'variant': 'line',
        'series': [
          {
            'name': 'a',
            'data': {'x': 1},
          },
        ],
      });
      final select = tester.widget<OiSelect<String>>(find.byKey(const ValueKey('style-variant')));
      expect([for (final option in select.options) option.value], ['line', 'area', 'scatter']);

      await _rowsFor(tester, const {
        'type': 'Chart',
        'variant': 'scatter',
        'points': [
          {'x': 0, 'y': 1},
        ],
      });
      final points = tester.widget<OiSelect<String>>(find.byKey(const ValueKey('style-variant')));
      expect([for (final option in points.options) option.value], ['scatter']);
      expect(points.enabled, isFalse, reason: 'nothing to switch to');
    });
  });

  group('chart data grid', () {
    testWidgets('shows one label and value row per entry', (tester) async {
      await _gridFor(tester, _barChart);
      expect(find.byType(EditableText), findsNWidgets(6));
    });

    testWidgets('renames a label in place, keeping the order', (tester) async {
      final patches = await _gridFor(tester, _barChart);
      await _commitField(tester, 2, 'X');
      expect(patches.single, {
        'data': {'A': 3, 'X': 5, 'C': 2},
      });
    });

    testWidgets('a duplicate or empty label is dropped', (tester) async {
      final patches = await _gridFor(tester, _barChart);
      await _commitField(tester, 2, 'A');
      await _commitField(tester, 2, '');
      expect(patches, isEmpty);
    });

    testWidgets('edits a value, writing integers as integers', (tester) async {
      final patches = await _gridFor(tester, _barChart);
      await _commitField(tester, 1, '7');
      expect(patches.single, {
        'data': {'A': 7, 'B': 5, 'C': 2},
      });
      await _commitField(tester, 3, '2.5');
      expect(patches.last, {
        'data': {'A': 3, 'B': 2.5, 'C': 2},
      });
    });

    testWidgets('adds a row with a fresh label', (tester) async {
      final patches = await _gridFor(tester, _barChart);
      await tester.tap(find.bySemanticsLabel('Add data row'));
      await tester.pump();
      expect(patches.single, {
        'data': {'A': 3, 'B': 5, 'C': 2, 'D': 0},
      });
    });

    testWidgets('removes a row, but never the last one', (tester) async {
      final patches = await _gridFor(tester, _barChart);
      await tester.tap(find.bySemanticsLabel('Remove row 1'));
      await tester.pump();
      expect(patches.single, {
        'data': {'A': 3, 'C': 2},
      });

      final last = await _gridFor(tester, const {
        'type': 'Chart',
        'variant': 'bar',
        'data': {'A': 1},
      });
      await tester.tap(find.bySemanticsLabel('Remove row 0'));
      await tester.pump();
      expect(last, isEmpty);
    });

    testWidgets('reorders rows up and down within bounds', (tester) async {
      final patches = await _gridFor(tester, _barChart);
      await tester.tap(find.bySemanticsLabel('Move row 1 up'));
      await tester.pump();
      expect(patches.single, {
        'data': {'B': 5, 'A': 3, 'C': 2},
      });
      await tester.tap(find.bySemanticsLabel('Move row 0 up'));
      await tester.pump();
      expect(patches, hasLength(1), reason: 'the first row cannot move up');
      await tester.tap(find.bySemanticsLabel('Move row 2 down'));
      await tester.pump();
      expect(patches, hasLength(1), reason: 'the last row cannot move down');
    });

    testWidgets('a series chart shows the series editor instead of a summary', (tester) async {
      final patches = await _gridFor(tester, const {
        'type': 'Chart',
        'variant': 'line',
        'series': [
          {
            'name': 'a',
            'data': {'x': 1},
          },
          {
            'name': 'b',
            'data': {'x': 2},
          },
        ],
      });
      expect(find.byKey(const ValueKey('chart-series-editor')), findsOneWidget);
      expect(find.byKey(const ValueKey('series-name-0')), findsOneWidget);
      expect(patches, isEmpty);
    });

    testWidgets('a points chart shows the points editor', (tester) async {
      await _gridFor(tester, const {
        'type': 'Chart',
        'variant': 'scatter',
        'points': [
          {'x': 1, 'y': 2},
          {'x': 2, 'y': 3},
          {'x': 3, 'y': 1},
        ],
      });
      expect(find.byKey(const ValueKey('chart-points-editor')), findsOneWidget);
      expect(find.byKey(const ValueKey('point-label-2')), findsOneWidget);
    });
  });

  group('through the inspector', () {
    Map<String, Object?> deck() => {
      'fluvieSpec': 1,
      'size': {'width': 320, 'height': 180},
      'fps': 30,
      'scenes': [
        {
          'duration': '60f',
          'layout': 'canvas',
          'children': [
            {
              'id': 'el-chart',
              'type': 'Chart',
              'variant': 'bar',
              'data': {'A': 3, 'B': 5},
              'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5},
            },
            {
              'id': 'el-frame',
              'type': 'DeviceFrame',
              'variant': 'phone',
              'notch': true,
              'child': {'type': 'Text', 'text': 'F'},
              'transform': {'x': 0.2, 'y': 0.2, 'w': 0.3, 'h': 0.3},
            },
          ],
        },
      ],
    };

    Future<DocumentHistory> pumpInspector(WidgetTester tester, String selected) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final history = DocumentHistory(EditorDocument.fromJson(deck()));
      container.read(selectionProvider.notifier).select({selected});
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
      return history;
    }

    testWidgets('the chart data grid edits the document undoably', (tester) async {
      final history = await pumpInspector(tester, 'el-chart');
      expect(find.text('Data'), findsOneWidget);
      final valueField = find
          .descendant(
            of: find.byKey(const ValueKey('chart-data-grid')),
            matching: find.byType(EditableText),
          )
          .at(1);
      await tester.enterText(valueField, '9');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(history.document.elementJson('el-chart')!['data'], {'A': 9, 'B': 5});
      history.undo();
      expect(history.document.elementJson('el-chart')!['data'], {'A': 3, 'B': 5});
    });

    testWidgets('a null in a patch removes the key from the document', (tester) async {
      final history = await pumpInspector(tester, 'el-frame');
      await tester.tap(find.byKey(const ValueKey('style-variant')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('tablet').last);
      await tester.pumpAndSettle();
      final frame = history.document.elementJson('el-frame')!;
      expect(frame['variant'], 'tablet');
      expect(frame.containsKey('notch'), isFalse, reason: 'a tablet takes no notch');
      history.undo();
      expect(history.document.elementJson('el-frame')!['notch'], isTrue);
    });
  });
}
