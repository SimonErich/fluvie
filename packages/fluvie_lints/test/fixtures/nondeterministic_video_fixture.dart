import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' as f;

f.Video build() => f.Video(
  scenes: [
    f.Scene(
      duration: const f.Time.seconds(1),
      children: [
        f.FrameBuilder(
          (_) => Text(
            [
              DateTime.now(),
              DateTime.timestamp(),
              math.Random().nextDouble(),
              math.Random(null).nextDouble(),
              math.Random.secure().nextDouble(),
              math.Random(42).nextDouble(),
              DateTime.utc(2026),
            ].join(' '),
          ),
        ),
      ],
    ),
  ],
);
