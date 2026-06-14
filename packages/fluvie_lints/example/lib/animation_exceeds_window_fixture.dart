// Fixture: a literal animation duration longer than its literal same-unit
// window trips animation_exceeds_window; its tail would be clipped.
// ignore_for_file: unused_local_variable

import 'package:flutter/widgets.dart' hide Animation;
import 'package:fluvie/fluvie.dart';

Widget build() {
  return const Box().animate([
    // expect_lint: animation_exceeds_window
    Animation.fadeIn(duration: 90.frames),
  ], window: 0.frames.to(60.frames));
}
