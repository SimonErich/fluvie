// Fixture: two full-window animations writing the same Keyframe field trip
// conflicting_keyframe_fields; the later write silently wins. Both writes are
// flagged, so both carry the marker.
// ignore_for_file: unused_local_variable

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';

Widget build() {
  return const Box().animate([
    // expect_lint: conflicting_keyframe_fields
    Animation.from(const Keyframe(opacity: 0)),
    // expect_lint: conflicting_keyframe_fields
    Animation.to(const Keyframe(opacity: 1)),
  ]);
}
