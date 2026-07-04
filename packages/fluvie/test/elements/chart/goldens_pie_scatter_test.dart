// Epic 10.3 WI-11 (10.3 ACCEPTANCE, D7/D9/D10): the pie / donut / scatter reveal
// goldens. The pie and donut sweeps mount the real `Chart` widget through the
// frame clock at the frames mapping to 0.3 / 0.7 / 1.0 of a 30-frame reveal
// (`[9, 21, 30]`), so a single file shows the angular sweep in motion. The
// `scatter_pop` golden freezes one mid frame where the markers are mid-pop, and
// `scatter_stagger` freezes a frame where the staggered markers form a pop wave.
// Subjects are font-free (colored geometry only) so the goldens carry zero font
// variance.
@Tags(['golden'])
library;

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart' show Tags;
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/chart/chart.dart';
import 'package:fluvie/src/elements/chart/data/chart_point.dart';

import '../../animation/helpers/golden_frame.dart';

const _pieData = {'A': 1, 'B': 3, 'C': 2, 'D': 4};
const _revealFrames = [9, 21, 30];

const _points = [
  ChartPoint(x: 1, y: 2),
  ChartPoint(x: 2, y: 5),
  ChartPoint(x: 3, y: 1),
  ChartPoint(x: 4, y: 4),
  ChartPoint(x: 5, y: 3),
];

Widget _pie() => Chart.pie(data: _pieData, reveal: const Time.frames(30));

Widget _donut() => Chart.donut(data: _pieData, reveal: const Time.frames(30), innerRadius: 0.55);

Widget _scatter() => Chart.scatter(points: _points, reveal: const Time.frames(30));

Widget _scatterStaggered() => Chart.scatter(
  points: _points,
  reveal: const Time.frames(18),
  stagger: const Stagger.each(Time.frames(6)),
);

Future<void> main() async {
  await goldenMotionFrames(
    description: "Chart.pie sweeps its segments clockwise from 12 o'clock",
    fileName: 'pie_sweep',
    frames: _revealFrames,
    subject: _pie,
  );
  await goldenMotionFrames(
    description: 'Chart.donut sweeps its segments and leaves an inner hole',
    fileName: 'donut_sweep',
    frames: _revealFrames,
    subject: _donut,
  );
  await goldenMotionFrames(
    description: 'Chart.scatter pops its markers in with a spring scale',
    fileName: 'scatter_pop',
    frames: const [10],
    subject: _scatter,
  );
  await goldenMotionFrames(
    description: 'Chart.scatter with Stagger.each pops the markers in a wave',
    fileName: 'scatter_stagger',
    frames: const [12],
    subject: _scatterStaggered,
  );
}
