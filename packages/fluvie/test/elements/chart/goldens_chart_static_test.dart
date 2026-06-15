// Epic 10.1 WI-5 (10.1 ACCEPTANCE, D8/D9/D10): the static-chart golden. A fully
// revealed (progress 1.0) bar chart with axes, painted over the fallback tokens
// through the WI-1..WI-4 machinery — the scales (CategoryScale + LinearScale),
// the ChartPainter base, and the shared axis toolkit. The subject is font-free
// (colored geometry only, no axis labels), so the golden is byte-stable. The
// `Chart` element lands in Epic 10.2; this proves the core renders coherently.
@Tags(['golden'])
library;

import 'dart:ui' show Canvas, Paint, Rect, Size;

import 'package:flutter/widgets.dart' show CustomPaint, SizedBox, Widget;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/elements/chart/painter/axis_painter.dart';
import 'package:fluvie/src/elements/chart/painter/chart_painter.dart';
import 'package:fluvie/src/elements/chart/scale/chart_scale.dart';
import 'package:fluvie/src/theme/fluvie_tokens.dart';

import '../../animation/helpers/golden_frame.dart';

/// A self-contained bar-chart painter for the static golden: it draws axes plus
/// one rect per category, each grown to `value × progress` from the baseline.
final class _BarProbePainter extends ChartPainter {
  _BarProbePainter({
    required super.plotRect,
    required super.progress,
    required super.tokens,
    required this.data,
  }) : category = CategoryScale(
         categories: data.keys.toList(),
         pixelMin: plotRect.left,
         pixelMax: plotRect.right,
         padding: 0.3,
       ),
       value = LinearScale.niceBounds(
         min: 0,
         max: data.values.fold<num>(0, (m, v) => v > m ? v : m),
         pixelMin: plotRect.bottom,
         pixelMax: plotRect.top,
       );

  final Map<String, num> data;
  final CategoryScale category;
  final LinearScale value;

  @override
  void paintChart(Canvas canvas, Size size) {
    drawAxes(canvas, valueScale: value, plot: plotRect, tickCount: 4, tokens: tokens);
    final paint = Paint();
    var index = 0;
    for (final entry in data.entries) {
      paint.color = tokens.palette.colorAt(index);
      final left = category.leftEdgeOf(entry.key)!;
      final right = category.rightEdgeOf(entry.key)!;
      final top = value.toPixel(entry.value * progress);
      canvas.drawRect(Rect.fromLTRB(left, top, right, value.baselinePixel), paint);
      index++;
    }
  }
}

Widget _barChart() {
  const gutters = ChartGutters(left: 8, bottom: 8, top: 8, right: 8);
  return CustomPaint(
    painter: _BarProbePainter(
      plotRect: ChartPainter.computePlotRect(const Size(120, 120), gutters),
      progress: 1,
      tokens: const FluvieTokens.fallback(),
      data: const {'A': 30, 'B': 45, 'C': 80, 'D': 60},
    ),
    child: const SizedBox(width: 120, height: 120),
  );
}

Future<void> main() async {
  await goldenMotionFrames(
    description: 'Chart core: a fully-revealed bar chart with axes (fallback tokens)',
    fileName: 'chart_bar_static',
    frames: const [60],
    subject: _barChart,
  );
}
