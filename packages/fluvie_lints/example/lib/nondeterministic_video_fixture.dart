import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' as f;

f.Video build() => f.Video(
  scenes: [
    f.Scene(
      duration: const f.Time.seconds(1),
      children: [
        // The fixture deliberately covers deterministic checks inside the experimental builder.
        // ignore: experimental_member_use
        f.FrameBuilder(
          (_) => Text(
            [
              // expect_lint: nondeterministic_video
              DateTime.now(),
              // expect_lint: nondeterministic_video
              DateTime.timestamp(),
              // expect_lint: nondeterministic_video
              math.Random().nextDouble(),
              // expect_lint: nondeterministic_video
              math.Random(null).nextDouble(),
              // expect_lint: nondeterministic_video
              math.Random.secure().nextDouble(),
              math.Random(42).nextDouble(),
              DateTime.utc(2026),
              // ignore: nondeterministic_video
              DateTime.now(),
            ].join(' '),
          ),
        ),
      ],
    ),
  ],
);
