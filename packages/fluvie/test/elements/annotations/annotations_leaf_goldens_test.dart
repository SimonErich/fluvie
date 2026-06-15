// WI-21 (§15, decision D-Annotations): the leaf-annotation goldens. Shape /
// Arrow / Connector are frame-driven leaf painters, so each golden mounts the
// real widget through the golden frame clock. `arrow_draw_on` freezes the arrow
// mid-reveal (frame 15 of a 30-frame draw-in) where the shaft is half-drawn and
// the head not yet shown; `connector` shows a completed elbow connector. The
// stroke color comes from the fallback tokens, so the goldens are font-free and
// stable.
@Tags(['golden'])
library;

import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart' show Tags;
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/annotations/arrow.dart';
import 'package:fluvie/src/elements/annotations/connector.dart';

import '../../animation/helpers/golden_frame.dart';

Widget _arrow() => const Arrow.to(
  from: Offset(20, 100),
  to: Offset(100, 20),
  drawIn: Time.frames(30),
  strokeWidth: 4,
  headLength: 18,
);

Widget _connector() => const Connector(
  from: Offset(20, 30),
  to: Offset(100, 90),
  elbow: true,
  strokeWidth: 3,
);

Future<void> main() async {
  await goldenMotionFrames(
    description: 'Arrow draws its shaft on toward the head over its reveal',
    fileName: 'arrow_draw_on',
    frames: const [15],
    subject: _arrow,
  );
  await goldenMotionFrames(
    description: 'Connector elbows between two explicit points',
    fileName: 'connector',
    frames: const [30],
    subject: _connector,
  );
}
