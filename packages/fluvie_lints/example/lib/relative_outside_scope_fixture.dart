// Fixture: a relative time as a Scene duration has no enclosing window to
// scale, so relative_outside_scope flags it. A scene defines its own scope.
// ignore_for_file: unused_local_variable

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';

Widget build() {
  // expect_lint: relative_outside_scope
  return Scene(duration: 0.5.relative);
}
