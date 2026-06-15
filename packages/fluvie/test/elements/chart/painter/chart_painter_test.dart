// Epic 10.1 WI-4 (D8/D3): the painter base + the shared axis/legend toolkit.
// The base computes a deterministic plot rect (size minus gutters) and repaints
// only when progress/geometry/tokens change (frame-correct, never time-based).
// The axis/legend layout math lives in pure free functions probed here without
// a canvas; the actual draw calls are covered by the WI-5 golden.

import 'dart:ui' show Canvas, Color, Offset, Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/elements/chart/painter/axis_painter.dart';
import 'package:fluvie/src/elements/chart/painter/chart_painter.dart';
import 'package:fluvie/src/elements/chart/painter/legend_painter.dart';
import 'package:fluvie/src/elements/chart/scale/chart_scale.dart';
import 'package:fluvie/src/theme/fluvie_tokens.dart';

/// A concrete [ChartPainter] that records whether [paintChart] ran, so the base
/// behavior (plot rect, shouldRepaint) is testable without a real chart type.
final class _ProbePainter extends ChartPainter {
  _ProbePainter({required super.plotRect, required super.progress, required super.tokens});

  @override
  void paintChart(Canvas canvas, Size size) {}
}

void main() {
  group('ChartGutters value equality', () {
    test('equal insets are value-equal with a matching hashCode', () {
      const a = ChartGutters(left: 8, top: 4, right: 2, bottom: 6);
      const b = ChartGutters(left: 8, top: 4, right: 2, bottom: 6);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a differing inset is not equal', () {
      const a = ChartGutters(left: 8, top: 4, right: 2, bottom: 6);
      expect(a, isNot(const ChartGutters(left: 9, top: 4, right: 2, bottom: 6)));
    });
  });

  group('AxisGridline value equality', () {
    test('equal lines are value-equal with a matching hashCode', () {
      const a = AxisGridline(left: 0, right: 100, y: 50);
      const b = AxisGridline(left: 0, right: 100, y: 50);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a differing field is not equal', () {
      const a = AxisGridline(left: 0, right: 100, y: 50);
      expect(a, isNot(const AxisGridline(left: 0, right: 100, y: 51)));
    });
  });

  group('ChartPainter.plotRect', () {
    test('insets the size by the gutters', () {
      final rect = ChartPainter.computePlotRect(
        const Size(200, 100),
        const ChartGutters(left: 30, bottom: 20, top: 10, right: 5),
      );
      expect(rect, const Rect.fromLTRB(30, 10, 195, 80));
    });

    test('zero gutters give the whole size', () {
      final rect = ChartPainter.computePlotRect(const Size(200, 100), ChartGutters.none);
      expect(rect, const Rect.fromLTWH(0, 0, 200, 100));
    });

    test('clamps to a non-negative rect when gutters exceed the size', () {
      final rect = ChartPainter.computePlotRect(
        const Size(20, 20),
        const ChartGutters(left: 30, bottom: 30),
      );
      expect(rect.width, greaterThanOrEqualTo(0));
      expect(rect.height, greaterThanOrEqualTo(0));
    });
  });

  group('ChartPainter.shouldRepaint', () {
    const tokens = FluvieTokens.fallback();
    final base = _ProbePainter(
      plotRect: const Rect.fromLTWH(0, 0, 100, 100),
      progress: 0.5,
      tokens: tokens,
    );

    test('false against an identical painter', () {
      final same = _ProbePainter(
        plotRect: const Rect.fromLTWH(0, 0, 100, 100),
        progress: 0.5,
        tokens: tokens,
      );
      expect(base.shouldRepaint(same), isFalse);
    });

    test('true when the progress changes', () {
      final moved = _ProbePainter(
        plotRect: const Rect.fromLTWH(0, 0, 100, 100),
        progress: 0.6,
        tokens: tokens,
      );
      expect(base.shouldRepaint(moved), isTrue);
    });

    test('true when the plot rect changes', () {
      final resized = _ProbePainter(
        plotRect: const Rect.fromLTWH(0, 0, 120, 100),
        progress: 0.5,
        tokens: tokens,
      );
      expect(base.shouldRepaint(resized), isTrue);
    });

    test('false against equal tokens, true against different tokens', () {
      final sameTokens = _ProbePainter(
        plotRect: const Rect.fromLTWH(0, 0, 100, 100),
        progress: 0.5,
        tokens: const FluvieTokens.fallback(),
      );
      expect(base.shouldRepaint(sameTokens), isFalse);
      final recolored = _ProbePainter(
        plotRect: const Rect.fromLTWH(0, 0, 100, 100),
        progress: 0.5,
        tokens: const FluvieTokens(
          palette: ChartPalette([Color(0xFF010203)]),
          axisColor: Color(0xFF111111),
          gridColor: Color(0xFF222222),
          labelColor: Color(0xFF333333),
        ),
      );
      expect(base.shouldRepaint(recolored), isTrue);
    });
  });

  group('axisGridlines', () {
    test('places a horizontal gridline at each value tick', () {
      const scale = LinearScale(domainMin: 0, domainMax: 100, pixelMin: 100, pixelMax: 0);
      const plot = Rect.fromLTWH(0, 0, 200, 100);
      final lines = axisGridlines(valueScale: scale, plot: plot, tickCount: 4);
      // 5 ticks at y = 100,75,50,25,0 within the plot's x extent.
      expect(lines.length, 5);
      expect(lines.first.y, 100);
      expect(lines.last.y, 0);
      expect(lines.every((g) => g.left == plot.left && g.right == plot.right), isTrue);
    });

    test('a zero tick count yields the two domain endpoints', () {
      const scale = LinearScale(domainMin: 0, domainMax: 10, pixelMin: 100, pixelMax: 0);
      const plot = Rect.fromLTWH(0, 0, 200, 100);
      expect(axisGridlines(valueScale: scale, plot: plot, tickCount: 0).length, 2);
    });
  });

  group('legendLayout', () {
    test('flows n swatches left to right with a deterministic step', () {
      final rects = legendLayout(
        count: 3,
        origin: const Offset(10, 5),
        swatch: 12,
        step: 60,
      );
      expect(rects.length, 3);
      expect(rects[0], const Rect.fromLTWH(10, 5, 12, 12));
      expect(rects[1], const Rect.fromLTWH(70, 5, 12, 12));
      expect(rects[2], const Rect.fromLTWH(130, 5, 12, 12));
    });

    test('an empty legend yields no rects', () {
      expect(legendLayout(count: 0, origin: Offset.zero, swatch: 10, step: 40), isEmpty);
    });
  });
}
