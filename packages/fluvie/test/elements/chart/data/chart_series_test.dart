// Epic 10.1 WI-1 (D4): the chart data value types. `ChartPoint` and
// `ChartSeries` mirror the `Particles` value-type discipline — immutable, value
// equal by every field (with deep `Map`/`List` equality), const where possible,
// and stable `hashCode`/`toString`. They live under `elements/chart/data/`
// because the chart owns its data shapes (they are not a cross-layer currency).

import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/elements/chart/data/chart_point.dart';
import 'package:fluvie/src/elements/chart/data/chart_series.dart';

const _red = Color(0xFFFF0000);
const _blue = Color(0xFF0000FF);

void main() {
  group('ChartPoint', () {
    test('carries x, y, and an optional label', () {
      const point = ChartPoint(x: 1.5, y: 3, label: 'p');
      expect(point.x, 1.5);
      expect(point.y, 3);
      expect(point.label, 'p');
    });

    test('label defaults to null', () {
      const point = ChartPoint(x: 0, y: 0);
      expect(point.label, isNull);
    });

    test('is value-equal by every field', () {
      const a = ChartPoint(x: 1, y: 2, label: 'a');
      const b = ChartPoint(x: 1, y: 2, label: 'a');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differs when any field differs', () {
      const base = ChartPoint(x: 1, y: 2, label: 'a');
      expect(base, isNot(const ChartPoint(x: 9, y: 2, label: 'a')));
      expect(base, isNot(const ChartPoint(x: 1, y: 9, label: 'a')));
      expect(base, isNot(const ChartPoint(x: 1, y: 2, label: 'b')));
      expect(base, isNot(const ChartPoint(x: 1, y: 2)));
    });

    test('is const-constructible (compile-time value)', () {
      expect(identical(const ChartPoint(x: 1, y: 2), const ChartPoint(x: 1, y: 2)), isTrue);
    });

    test('toString names x and y', () {
      expect(const ChartPoint(x: 1, y: 2).toString(), contains('1'));
      expect(const ChartPoint(x: 1, y: 2).toString(), contains('2'));
    });
  });

  group('ChartSeries.values (category → value)', () {
    test('carries its name, data map, and color', () {
      const series = ChartSeries.values(
        name: 'Sales',
        data: {'Jan': 30, 'Feb': 45},
        color: _red,
      );
      expect(series.name, 'Sales');
      expect(series.data, const {'Jan': 30, 'Feb': 45});
      expect(series.color, _red);
      expect(series.points, isNull);
    });

    test('color defaults to null', () {
      const series = ChartSeries.values(name: 's', data: {'A': 1});
      expect(series.color, isNull);
    });

    test('is value-equal with deep map equality', () {
      const a = ChartSeries.values(name: 's', data: {'A': 1, 'B': 2});
      const b = ChartSeries.values(name: 's', data: {'A': 1, 'B': 2});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differs when the data map differs', () {
      const base = ChartSeries.values(name: 's', data: {'A': 1, 'B': 2});
      expect(base, isNot(const ChartSeries.values(name: 's', data: {'A': 1, 'B': 9})));
      expect(base, isNot(const ChartSeries.values(name: 's', data: {'A': 1})));
      expect(base, isNot(const ChartSeries.values(name: 't', data: {'A': 1, 'B': 2})));
    });

    test('differs when the color differs', () {
      const a = ChartSeries.values(name: 's', data: {'A': 1}, color: _red);
      const b = ChartSeries.values(name: 's', data: {'A': 1}, color: _blue);
      expect(a, isNot(b));
    });
  });

  group('ChartSeries.points (x/y points)', () {
    test('carries its name, point list, and color', () {
      const series = ChartSeries.points(
        name: 'Cloud',
        data: [ChartPoint(x: 1, y: 2), ChartPoint(x: 3, y: 4)],
        color: _blue,
      );
      expect(series.name, 'Cloud');
      expect(series.points, const [ChartPoint(x: 1, y: 2), ChartPoint(x: 3, y: 4)]);
      expect(series.color, _blue);
      expect(series.data, isNull);
    });

    test('is value-equal with deep list equality', () {
      const a = ChartSeries.points(name: 's', data: [ChartPoint(x: 1, y: 2)]);
      const b = ChartSeries.points(name: 's', data: [ChartPoint(x: 1, y: 2)]);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differs when the point list differs', () {
      const base = ChartSeries.points(name: 's', data: [ChartPoint(x: 1, y: 2)]);
      expect(base, isNot(const ChartSeries.points(name: 's', data: [ChartPoint(x: 9, y: 2)])));
      expect(
        base,
        isNot(
          const ChartSeries.points(
            name: 's',
            data: [ChartPoint(x: 1, y: 2), ChartPoint(x: 3, y: 4)],
          ),
        ),
      );
    });

    test('a values series never equals a points series', () {
      const values = ChartSeries.values(name: 's', data: {'A': 1});
      const points = ChartSeries.points(name: 's', data: [ChartPoint(x: 0, y: 1)]);
      expect(values, isNot(points));
    });
  });

  group('ChartSeries — toString', () {
    test('names the series name', () {
      expect(const ChartSeries.values(name: 'Sales', data: {'A': 1}).toString(), contains('Sales'));
      expect(const ChartSeries.points(name: 'Cloud', data: []).toString(), contains('Cloud'));
    });
  });
}
