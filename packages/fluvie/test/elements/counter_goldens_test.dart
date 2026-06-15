// WI-18 (D10/D14, §15): the Counter goldens. The count is frame-driven, so each
// scenario mounts the same Counter at a different frame and the golden shows the
// formatted number it painted (Ahem in ci goldens, so it is font-free and
// byte-stable). counter_mid snapshots a mid-count value; counter_end snapshots
// the final value.
@Tags(['golden'])
library;

import 'package:flutter/widgets.dart' show TextStyle;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/elements/counter.dart';

import '../animation/helpers/golden_frame.dart';

Future<void> main() async {
  await goldenMotionFrames(
    description: 'Counter: a mid-count value at the temporal midpoint',
    fileName: 'counter_mid',
    frames: const [15],
    subject: () => const Counter(
      to: 48230,
      style: TextStyle(fontSize: 16),
    ),
  );

  await goldenMotionFrames(
    description: 'Counter: the final value once the count completes',
    fileName: 'counter_end',
    frames: const [60],
    subject: () => const Counter(
      to: 48230,
      style: TextStyle(fontSize: 16),
    ),
  );
}
