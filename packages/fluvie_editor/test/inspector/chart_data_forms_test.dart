import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

const Map<String, Object?> _mapChart = {
  'type': 'Chart',
  'variant': 'bar',
  'data': {'A': 3, 'B': 5.5},
};

void main() {
  group('chartDataFormOf', () {
    test('reads the present shape, map by default', () {
      expect(chartDataFormOf(_mapChart), ChartDataForm.map);
      expect(
        chartDataFormOf(const {
          'type': 'Chart',
          'series': [
            {
              'name': 'a',
              'data': {'x': 1},
            },
          ],
        }),
        ChartDataForm.series,
      );
      expect(
        chartDataFormOf(const {
          'type': 'Chart',
          'points': [
            {'x': 0, 'y': 1},
          ],
        }),
        ChartDataForm.points,
      );
      expect(chartDataFormOf(const {'type': 'Chart'}), ChartDataForm.map);
    });
  });

  group('chartFormsFor', () {
    test('mirrors the codec: bar family map-only, line family adds series', () {
      for (final variant in ['bar', 'pie', 'donut']) {
        expect(chartFormsFor(variant), [ChartDataForm.map], reason: variant);
      }
      for (final variant in ['line', 'area']) {
        expect(chartFormsFor(variant), [ChartDataForm.map, ChartDataForm.series], reason: variant);
      }
      expect(chartFormsFor('scatter'), ChartDataForm.values);
      expect(chartFormsFor(null), [ChartDataForm.map]);
    });
  });

  group('convertChartForm', () {
    test('map to a single series is lossless', () {
      final change = convertChartForm(_mapChart, ChartDataForm.series) as ChartFormPatch;
      expect(change.patch, {
        'data': null,
        'series': [
          {
            'name': 'Series 1',
            'data': {'A': 3, 'B': 5.5},
          },
        ],
      });
    });

    test('map to points writes indices as x and keys as labels', () {
      final change = convertChartForm(_mapChart, ChartDataForm.points) as ChartFormPatch;
      expect(change.patch, {
        'data': null,
        'points': [
          {'x': 0, 'y': 3, 'label': 'A'},
          {'x': 1, 'y': 5.5, 'label': 'B'},
        ],
      });
    });

    test('a single data-map series converts back to the map, wrapper dropped', () {
      final change =
          convertChartForm(const {
                'type': 'Chart',
                'variant': 'line',
                'series': [
                  {
                    'name': 'north',
                    'color': '#FF0000',
                    'data': {'A': 1, 'B': 2},
                  },
                ],
              }, ChartDataForm.map)
              as ChartFormPatch;
      expect(change.patch, {
        'series': null,
        'data': {'A': 1, 'B': 2},
      });
    });

    test('multiple series refuse the map form with a note', () {
      final change = convertChartForm(const {
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
      }, ChartDataForm.map);
      expect(change, isA<ChartFormRefusal>());
      expect((change as ChartFormRefusal).note, contains('single series'));
    });

    test('a points-holding series refuses the map form', () {
      final change = convertChartForm(const {
        'type': 'Chart',
        'variant': 'scatter',
        'series': [
          {
            'name': 'a',
            'points': [
              {'x': 1, 'y': 2},
            ],
          },
        ],
      }, ChartDataForm.map);
      expect(change, isA<ChartFormRefusal>());
    });

    test('index-aligned points convert to a map; real x data refuses', () {
      final aligned = convertChartForm(const {
        'type': 'Chart',
        'variant': 'scatter',
        'points': [
          {'x': 0, 'y': 3, 'label': 'A'},
          {'x': 1, 'y': 4},
        ],
      }, ChartDataForm.map);
      expect((aligned as ChartFormPatch).patch, {
        'points': null,
        'data': {'A': 3, 'P2': 4},
      });

      final real = convertChartForm(const {
        'type': 'Chart',
        'variant': 'scatter',
        'points': [
          {'x': 2, 'y': 3},
          {'x': 5, 'y': 4},
        ],
      }, ChartDataForm.map);
      expect(real, isA<ChartFormRefusal>());
      expect((real as ChartFormRefusal).note, contains('x'));
    });

    test('colliding point labels refuse the map form', () {
      final change = convertChartForm(const {
        'type': 'Chart',
        'variant': 'scatter',
        'points': [
          {'x': 0, 'y': 3, 'label': 'A'},
          {'x': 1, 'y': 4, 'label': 'A'},
        ],
      }, ChartDataForm.map);
      expect(change, isA<ChartFormRefusal>());
    });

    test('series and points only convert through the map form', () {
      final change = convertChartForm(const {
        'type': 'Chart',
        'variant': 'scatter',
        'points': [
          {'x': 0, 'y': 1},
        ],
      }, ChartDataForm.series);
      expect(change, isA<ChartFormRefusal>());
    });

    test('the map round-trips through both forms identically', () {
      final toSeries = (convertChartForm(_mapChart, ChartDataForm.series) as ChartFormPatch).patch;
      final asSeries = {'type': 'Chart', 'variant': 'line', ...toSeries}
        ..removeWhere((_, value) => value == null);
      final back = (convertChartForm(asSeries, ChartDataForm.map) as ChartFormPatch).patch;
      expect(back['data'], _mapChart['data']);

      final toPoints = (convertChartForm(_mapChart, ChartDataForm.points) as ChartFormPatch).patch;
      final asPoints = {'type': 'Chart', 'variant': 'scatter', ...toPoints}
        ..removeWhere((_, value) => value == null);
      final round = (convertChartForm(asPoints, ChartDataForm.map) as ChartFormPatch).patch;
      expect(round['data'], _mapChart['data']);
    });

    test('converting to the current form is a caller error', () {
      expect(() => convertChartForm(_mapChart, ChartDataForm.map), throwsArgumentError);
    });
  });
}
