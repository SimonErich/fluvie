// Fixture: a Trigger.whenEnds on a local Anchor that is never attached trips
// dangling_anchor. The resolver would have nothing to wait for.
// ignore_for_file: unused_local_variable

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';

Widget build() {
  final ghost = Anchor('ghost');
  // expect_lint: dangling_anchor
  final waitForGhost = Trigger.whenEnds(ghost);

  // intro is attached, so its Trigger is fine.
  final intro = Anchor('intro');
  final waitForIntro = Trigger.whenStarts(intro);
  return const Box().animate([
    Animation.fadeIn(at: waitForIntro),
  ], anchor: intro);
}
