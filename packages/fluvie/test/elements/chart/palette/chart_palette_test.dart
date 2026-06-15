// Epic 10.1 (WI-12 value): the chart series palette. `ChartPalette` holds an
// ordered list of colors and `colorAt(i)` cycles them modularly, so a chart
// with more segments than palette slots keeps assigning colors without running
// out. It mirrors the `Particles` value-type discipline.

import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/elements/chart/palette/chart_palette.dart';

const _a = Color(0xFFAA0000);
const _b = Color(0xFF00BB00);
const _c = Color(0xFF0000CC);

void main() {
  group('ChartPalette', () {
    test('carries its ordered colors', () {
      const palette = ChartPalette([_a, _b, _c]);
      expect(palette.colors, const [_a, _b, _c]);
    });

    test('colorAt returns the slot at the index within range', () {
      const palette = ChartPalette([_a, _b, _c]);
      expect(palette.colorAt(0), _a);
      expect(palette.colorAt(1), _b);
      expect(palette.colorAt(2), _c);
    });

    test('colorAt wraps modularly past the last slot', () {
      const palette = ChartPalette([_a, _b]);
      expect(palette.colorAt(2), _a);
      expect(palette.colorAt(3), _b);
      expect(palette.colorAt(4), _a);
    });

    test('is value-equal with deep list equality', () {
      const x = ChartPalette([_a, _b]);
      const y = ChartPalette([_a, _b]);
      expect(x, y);
      expect(x.hashCode, y.hashCode);
    });

    test('differs when the colors differ', () {
      const base = ChartPalette([_a, _b]);
      expect(base, isNot(const ChartPalette([_a, _c])));
      expect(base, isNot(const ChartPalette([_a])));
    });

    test('toString names the slot count', () {
      expect(const ChartPalette([_a, _b]).toString(), contains('2'));
    });

    test('colorAt rejects an empty palette instead of dividing by zero', () {
      // Build the empty palette via a runtime helper so the assert fires at
      // runtime; without the guard, colorAt would throw an integer division by
      // zero on `index % colors.length`.
      List<Color> empty() => const [];
      final palette = ChartPalette(empty());
      expect(() => palette.colorAt(0), throwsA(isA<AssertionError>()));
    });
  });
}
