// Fixture: an Anchor declared but referenced nowhere trips unused_anchor, with
// a remove-the-declaration quick-fix.
// ignore_for_file: unused_local_variable

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';

Widget build() {
  // expect_lint: unused_anchor
  final orphan = Anchor('orphan');

  // Referenced by a Trigger and attached: not flagged.
  final intro = Anchor('intro');
  Trigger.after(intro);
  return const Box().animate([Animation.fadeIn()], anchor: intro);
}
