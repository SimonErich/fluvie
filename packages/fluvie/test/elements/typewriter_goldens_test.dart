// WI-17 (D10, §15): the Typewriter goldens. The reveal is frame-driven, so each
// scenario mounts the same Typewriter at a different frame and the golden shows
// the substring it painted (Ahem in ci goldens, so text is font-free and
// byte-stable). typewriter_quarter snapshots an early reveal; typewriter_full
// snapshots the completed text with its blinking caret.
@Tags(['golden'])
library;

import 'package:flutter/widgets.dart' show TextStyle;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/elements/typewriter.dart';

import '../animation/helpers/golden_frame.dart';

Future<void> main() async {
  await goldenMotionFrames(
    description: 'Typewriter: an early quarter-revealed glyph run',
    fileName: 'typewriter_quarter',
    frames: const [6],
    subject: () => const Typewriter(
      'HELLO WORLD',
      style: TextStyle(fontSize: 16),
    ),
  );

  await goldenMotionFrames(
    description: 'Typewriter: the full text with a blinking caret on',
    fileName: 'typewriter_full',
    frames: const [40],
    subject: () => const Typewriter(
      'HELLO WORLD',
      caret: true,
      style: TextStyle(fontSize: 16),
    ),
  );
}
