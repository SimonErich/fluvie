// Fixture: an element whose anchor waits on itself is a degenerate trigger
// cycle, so cyclic_trigger flags the single offending .animate call.
// ignore_for_file: unused_local_variable

import 'package:flutter/widgets.dart' hide Animation;
import 'package:fluvie/fluvie.dart';

Widget build() {
  final loop = Anchor('loop');
  // expect_lint: cyclic_trigger
  return const Box().animate([
    Animation.fadeIn(at: Trigger.after(loop)),
  ], anchor: loop);
}
