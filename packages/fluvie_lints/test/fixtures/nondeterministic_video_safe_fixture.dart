import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' as f;

class Video {
  Video(Object value);
}

class Random {
  Random();
}

Object applicationClock() => DateTime.now();
Object applicationRandom() => math.Random();
Object unrelated() => Video(DateTime.now());
Object unresolved() => Unknown(DateTime.now());

f.Video build() => f.Video(
  scenes: [
    f.Scene(
      duration: const f.Time.seconds(1),
      children: [
        Text(Random().toString()),
        GestureDetector(
          onTap: () {
            DateTime.now();
            math.Random();
          },
          child: const Text('fixed'),
        ),
      ],
    ),
  ],
);
