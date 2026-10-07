import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/src/inspector/chart_data_section.dart';
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;

const Map<String, Object?> _seriesChart = {
  'type': 'Chart',
  'variant': 'line',
  'series': [
    {
      'name': 'north',
      'color': '#FF0000',
      'data': {'A': 1, 'B': 2},
    },
    {
      'name': 'south',
      'data': {'A': 3},
    },
  ],
};

const Map<String, Object?> _pointsChart = {
  'type': 'Chart',
  'variant': 'scatter',
  'points': [
    {'x': 0, 'y': 3, 'label': 'A'},
    {'x': 1, 'y': 4},
  ],
};

Future<List<Map<String, Object?>>> _pump(
  WidgetTester tester,
  Map<String, Object?> element,
) async {
  final patches = <Map<String, Object?>>[];
  await tester.pumpWidget(
    OiApp(
      title: 'test',
      theme: OiThemeData.dark(),
      home: Center(
        child: SizedBox(
          width: 280,
          height: 560,
          child: SingleChildScrollView(
            child: ChartDataSection(
              element: element,
              patch: (patch, {mergeGroup}) => patches.add(patch),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return patches;
}

Future<void> _commit(WidgetTester tester, Finder field, String text) async {
  await tester.enterText(field, text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

Future<void> _pickForm(WidgetTester tester, String option) async {
  await tester.tap(find.byKey(const ValueKey('chart-data-form')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  group('the series editor', () {
    testWidgets('renames a series; an empty name drops', (tester) async {
      final patches = await _pump(tester, _seriesChart);
      await _commit(tester, find.byKey(const ValueKey('series-name-1')), 'east');
      expect(patches.single['series'], [
        {
          'name': 'north',
          'color': '#FF0000',
          'data': {'A': 1, 'B': 2},
        },
        {
          'name': 'east',
          'data': {'A': 3},
        },
      ]);
      await _commit(tester, find.byKey(const ValueKey('series-name-1')), '');
      expect(patches, hasLength(1));
    });

    testWidgets('edits a series data map through the shared grid', (tester) async {
      final patches = await _pump(tester, _seriesChart);
      // The second series' single value row.
      final grids = find.byKey(const ValueKey('chart-map-grid'));
      final valueField = find.descendant(of: grids.last, matching: find.byType(EditableText)).at(1);
      await _commit(tester, valueField, '9');
      expect((patches.single['series']! as List)[1], {
        'name': 'south',
        'data': {'A': 9},
      });
    });

    testWidgets('adds and removes series, never below one', (tester) async {
      final patches = await _pump(tester, _seriesChart);
      await tester.tap(find.bySemanticsLabel('Add series'));
      await tester.pump();
      expect(patches.single['series']! as List, hasLength(3));
      expect((patches.single['series']! as List).last, {
        'name': 'Series 3',
        'data': {'A': 0},
      });

      await tester.tap(find.bySemanticsLabel('Remove series 0'));
      await tester.pump();
      final remaining = (patches.last['series']! as List).cast<Map<String, Object?>>();
      expect(remaining.single['name'], 'south');

      final lastOne = await _pump(tester, const {
        'type': 'Chart',
        'variant': 'line',
        'series': [
          {
            'name': 'only',
            'data': {'A': 1},
          },
        ],
      });
      await tester.tap(find.bySemanticsLabel('Remove series 0'));
      await tester.pump();
      expect(lastOne, isEmpty);
    });

    testWidgets('a scatter series chart offers no Add series', (tester) async {
      await _pump(tester, const {
        'type': 'Chart',
        'variant': 'scatter',
        'series': [
          {
            'name': 'only',
            'data': {'A': 1},
          },
        ],
      });
      expect(find.bySemanticsLabel('Add series'), findsNothing);
    });
  });

  group('the points editor', () {
    testWidgets('edits x, y, and label per row', (tester) async {
      final patches = await _pump(tester, _pointsChart);
      await _commit(tester, find.byKey(const ValueKey('point-label-1')), 'B');
      expect(patches.single['points'], [
        {'x': 0, 'y': 3, 'label': 'A'},
        {'x': 1, 'y': 4, 'label': 'B'},
      ]);
      await _commit(tester, find.byKey(const ValueKey('point-label-0')), '');
      expect(patches.last['points'], [
        {'x': 0, 'y': 3},
        {'x': 1, 'y': 4},
      ]);
    });

    testWidgets('adds, removes, and reorders points', (tester) async {
      final patches = await _pump(tester, _pointsChart);
      await tester.tap(find.bySemanticsLabel('Add point'));
      await tester.pump();
      expect((patches.single['points']! as List).last, {'x': 2, 'y': 0});

      await tester.tap(find.bySemanticsLabel('Move point 1 up'));
      await tester.pump();
      expect(patches.last['points'], [
        {'x': 1, 'y': 4},
        {'x': 0, 'y': 3, 'label': 'A'},
      ]);

      await tester.tap(find.bySemanticsLabel('Remove point 0'));
      await tester.pump();
      expect(patches.last['points'], [
        {'x': 1, 'y': 4},
      ]);
    });
  });

  group('the form switch', () {
    testWidgets('a line chart converts its map to a single series', (tester) async {
      final patches = await _pump(tester, const {
        'type': 'Chart',
        'variant': 'line',
        'data': {'A': 3},
      });
      await _pickForm(tester, 'series');
      expect(patches.single, {
        'data': null,
        'series': [
          {
            'name': 'Series 1',
            'data': {'A': 3},
          },
        ],
      });
    });

    testWidgets('a bar chart shows no form switch at all', (tester) async {
      await _pump(tester, const {
        'type': 'Chart',
        'variant': 'bar',
        'data': {'A': 3},
      });
      expect(find.byKey(const ValueKey('chart-data-form')), findsNothing);
    });

    testWidgets('a lossy conversion refuses with a visible note', (tester) async {
      final patches = await _pump(tester, _seriesChart);
      await _pickForm(tester, 'map');
      expect(patches, isEmpty);
      expect(find.byKey(const ValueKey('chart-form-note')), findsOneWidget);
      expect(find.textContaining('single series'), findsOneWidget);
    });

    testWidgets('index-aligned points convert back to a map', (tester) async {
      final patches = await _pump(tester, _pointsChart);
      await _pickForm(tester, 'map');
      expect(patches.single, {
        'points': null,
        'data': {'A': 3, 'P2': 4},
      });
    });
  });
}
