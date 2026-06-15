// Epic 10.2 WI-8 (10.2 ACCEPTANCE, D7/D9/D10): the bar / line / area reveal and
// stagger goldens. Each reveal golden mounts the real `Chart` widget through the
// frame clock at the frames mapping to 0.3 / 0.7 / 1.0 of a 30-frame reveal
// (`[9, 21, 30]`), so a single file shows the grow / draw-on / fill in motion.
// The `bar_stagger` golden freezes one mid frame where the staggered columns
// form a wave. Subjects are font-free (colored geometry only) so the goldens
// carry zero font variance.
@Tags(['golden'])
library;

import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart' show Tags;
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/chart/chart.dart';

import '../../animation/helpers/golden_frame.dart';

const _data = {'A': 30, 'B': 75, 'C': 45, 'D': 90, 'E': 60};
const _revealFrames = [9, 21, 30];

Widget _bar() => Chart.bar(data: _data, growIn: const Time.frames(30));

Widget _line() => Chart.line(data: _data, drawIn: const Time.frames(30));

Widget _area() => Chart.area(data: _data, drawIn: const Time.frames(30));

Widget _staggered() => Chart.bar(
  data: _data,
  growIn: const Time.frames(30),
  stagger: const Stagger.each(Time.frames(4)),
);

Future<void> main() async {
  await goldenMotionFrames(
    description: 'Chart.bar grows each column from the baseline over its reveal',
    fileName: 'bar_reveal',
    frames: _revealFrames,
    subject: _bar,
  );
  await goldenMotionFrames(
    description: 'Chart.line draws its polyline on left to right over its reveal',
    fileName: 'line_reveal',
    frames: _revealFrames,
    subject: _line,
  );
  await goldenMotionFrames(
    description: 'Chart.area fills under the sweeping line over its reveal',
    fileName: 'area_reveal',
    frames: _revealFrames,
    subject: _area,
  );
  await goldenMotionFrames(
    description: 'Chart.bar with Stagger.each rises the columns in a wave',
    fileName: 'bar_stagger',
    frames: const [14],
    subject: _staggered,
  );
}
