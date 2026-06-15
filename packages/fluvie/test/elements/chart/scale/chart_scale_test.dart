// Epic 10.1 WI-2 (D3): the pure chart scales. `LinearScale` maps a value range
// to a pixel range (interpolation + clamping + nice bounds + ticks +
// zero-baseline); `CategoryScale` maps ordered keys to band centers/edges with
// padding. No canvas, no widget — pure math, unit-tested without a painter, and
// degenerate inputs (all-equal, single category, empty) must never produce NaN.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/elements/chart/scale/chart_scale.dart';

void main() {
  group('LinearScale interpolation', () {
    test('maps the domain min to pixelMin and max to pixelMax', () {
      const scale = LinearScale(domainMin: 0, domainMax: 100, pixelMin: 0, pixelMax: 200);
      expect(scale.toPixel(0), 0);
      expect(scale.toPixel(100), 200);
    });

    test('interpolates linearly within the domain', () {
      const scale = LinearScale(domainMin: 0, domainMax: 100, pixelMin: 0, pixelMax: 200);
      expect(scale.toPixel(50), 100);
      expect(scale.toPixel(25), 50);
    });

    test('inverts a pixel range (top-down y axis: pixelMin > pixelMax)', () {
      // A y axis grows upward: domain 0 -> pixel 200 (bottom), domain 100 ->
      // pixel 0 (top).
      const scale = LinearScale(domainMin: 0, domainMax: 100, pixelMin: 200, pixelMax: 0);
      expect(scale.toPixel(0), 200);
      expect(scale.toPixel(100), 0);
      expect(scale.toPixel(50), 100);
    });

    test('clamps values outside the domain to the pixel bounds', () {
      const scale = LinearScale(domainMin: 0, domainMax: 100, pixelMin: 0, pixelMax: 200);
      expect(scale.toPixel(-50), 0);
      expect(scale.toPixel(150), 200);
    });
  });

  group('LinearScale.niceBounds', () {
    test('rounds a ragged max up to a human tick', () {
      final scale = LinearScale.niceBounds(min: 0, max: 87, pixelMin: 0, pixelMax: 100);
      expect(scale.domainMin, 0);
      expect(scale.domainMax, 100);
    });

    test('keeps zero as the baseline when the data is non-negative', () {
      final scale = LinearScale.niceBounds(min: 12, max: 80, pixelMin: 0, pixelMax: 100);
      expect(scale.domainMin, 0);
      expect(scale.domainMax, greaterThanOrEqualTo(80));
    });

    test('all-equal values yield a safe non-degenerate domain (no NaN)', () {
      final scale = LinearScale.niceBounds(min: 5, max: 5, pixelMin: 0, pixelMax: 100);
      expect(scale.domainMin, isNot(equals(scale.domainMax)));
      expect(scale.toPixel(5).isNaN, isFalse);
      expect(scale.toPixel(5).isFinite, isTrue);
    });

    test('empty-ish all-zero values stay finite (no NaN)', () {
      final scale = LinearScale.niceBounds(min: 0, max: 0, pixelMin: 0, pixelMax: 100);
      expect(scale.toPixel(0).isNaN, isFalse);
      expect(scale.domainMax, greaterThan(scale.domainMin));
    });

    test('a negative min rounds the lower bound down to a nice tick', () {
      // Negative data takes the _niceFloor path (the mirror of _niceCeil): the
      // lower bound rounds away from zero to -100 and the upper bound to 100.
      final scale = LinearScale.niceBounds(min: -87, max: 42, pixelMin: 0, pixelMax: 100);
      expect(scale.domainMin, -100);
      expect(scale.domainMax, 50);
      expect(scale.toPixel(-87).isFinite, isTrue);
    });

    test('a value where log10 floors low rounds up via the 10x fallback', () {
      // 1000.0000000000001 floors its log10 to 2 (magnitude 100), so the
      // 1/2/5/10 x loop tops out at 1000 < value and falls through to the final
      // 10 x magnitude branch rather than returning inside the loop.
      final scale = LinearScale.niceBounds(
        min: 0,
        max: 1000.0000000000001,
        pixelMin: 0,
        pixelMax: 100,
      );
      expect(scale.domainMax, 1000);
      expect(scale.domainMax.isFinite, isTrue);
    });
  });

  group('LinearScale.ticks', () {
    test('returns count+1 evenly spaced, deterministic tick values', () {
      const scale = LinearScale(domainMin: 0, domainMax: 100, pixelMin: 0, pixelMax: 200);
      final ticks = scale.ticks(4);
      expect(ticks, [0, 25, 50, 75, 100]);
    });

    test('a zero count yields just the domain endpoints', () {
      const scale = LinearScale(domainMin: 0, domainMax: 10, pixelMin: 0, pixelMax: 100);
      expect(scale.ticks(0), [0, 10]);
    });

    test('the zero-baseline pixel sits where the domain crosses zero', () {
      const scale = LinearScale(domainMin: 0, domainMax: 100, pixelMin: 200, pixelMax: 0);
      // Baseline is domain 0 -> pixel 200 (the bottom of an upward y axis).
      expect(scale.baselinePixel, 200);
    });

    test('the zero-baseline clamps into the domain when zero is outside', () {
      const scale = LinearScale(domainMin: 20, domainMax: 100, pixelMin: 200, pixelMax: 0);
      // Zero is below the domain min, so the baseline clamps to domain min's
      // pixel (200) rather than extrapolating off-axis.
      expect(scale.baselinePixel, 200);
    });
  });

  group('CategoryScale band layout', () {
    test('places n band centers evenly across the pixel extent', () {
      const scale = CategoryScale(
        categories: ['A', 'B', 'C', 'D'],
        pixelMin: 0,
        pixelMax: 400,
      );
      // Four bands across 400 px -> band width 100 -> centers at 50,150,250,350.
      expect(scale.centerOf('A'), 50);
      expect(scale.centerOf('B'), 150);
      expect(scale.centerOf('C'), 250);
      expect(scale.centerOf('D'), 350);
    });

    test('reports each band edge pair (left/right) with no padding', () {
      const scale = CategoryScale(categories: ['A', 'B'], pixelMin: 0, pixelMax: 200);
      expect(scale.leftEdgeOf('A'), 0);
      expect(scale.rightEdgeOf('A'), 100);
      expect(scale.leftEdgeOf('B'), 100);
      expect(scale.rightEdgeOf('B'), 200);
    });

    test('padding shrinks each band symmetrically around its center', () {
      const scale = CategoryScale(
        categories: ['A', 'B'],
        pixelMin: 0,
        pixelMax: 200,
        padding: 0.2,
      );
      // Band width 100, padding 0.2 -> bar width 80, centered: 10..90, 110..190.
      expect(scale.centerOf('A'), 50);
      expect(scale.bandWidth, closeTo(80, 1e-9));
      expect(scale.leftEdgeOf('A'), closeTo(10, 1e-9));
      expect(scale.rightEdgeOf('A'), closeTo(90, 1e-9));
    });

    test('a single category centers in the whole extent (no NaN)', () {
      const scale = CategoryScale(categories: ['Only'], pixelMin: 0, pixelMax: 100);
      expect(scale.centerOf('Only'), 50);
      expect(scale.bandWidth.isNaN, isFalse);
      expect(scale.bandWidth, 100);
    });

    test('no categories yields a zero band width and finite math (no NaN)', () {
      const scale = CategoryScale(categories: [], pixelMin: 0, pixelMax: 100);
      expect(scale.bandWidth.isNaN, isFalse);
      expect(scale.categories, isEmpty);
    });

    test('an unknown category center is null (lookup is safe)', () {
      const scale = CategoryScale(categories: ['A'], pixelMin: 0, pixelMax: 100);
      expect(scale.centerOf('Z'), isNull);
    });
  });

  group('ChartScale sealing', () {
    test('LinearScale and CategoryScale are both ChartScale', () {
      const ChartScale linear = LinearScale(
        domainMin: 0,
        domainMax: 1,
        pixelMin: 0,
        pixelMax: 1,
      );
      const ChartScale category = CategoryScale(categories: [], pixelMin: 0, pixelMax: 1);
      expect(linear, isA<ChartScale>());
      expect(category, isA<ChartScale>());
    });
  });
}
