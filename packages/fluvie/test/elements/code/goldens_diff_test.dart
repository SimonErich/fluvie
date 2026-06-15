// WI-11 (11.2 ACCEPTANCE, D-Diff): the animated line-diff golden. Mounts a real
// Code.diff through the frame clock at 0.3 / 0.7 / 1.0 of its reveal window, so a
// single golden file shows the motion mid-animation: the red-removed and
// green-inserted gutters and the vertical line motion are all visible. The ci
// variant proves layout on Ahem; the linux variant carries JetBrains Mono.
@Tags(['golden'])
library;

import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart' show Tags;
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/code/code.dart';
import 'package:fluvie/src/elements/code/code_reveal.dart';

import '../../animation/helpers/golden_frame.dart';

const _before =
    'class Counter {\n'
    '  int value = 0;\n'
    '  void reset() {\n'
    '    value = 0;\n'
    '  }\n'
    '}';

const _after =
    'class Counter {\n'
    '  int value = 1;\n'
    '  int step = 1;\n'
    '  void reset() {\n'
    '    value = 1;\n'
    '  }\n'
    '}';

const _diffSize = Size(360, 200);

Widget _diff() => const Code.diff(
  _before,
  _after,
  language: 'dart',
  reveal: CodeReveal.lineByLine(Time.frames(20)),
);

Future<void> main() async {
  await goldenMotionFrames(
    description: 'Code.diff animates add / remove / change with red and green gutters',
    fileName: 'code_diff',
    // The reveal window is 20 frames; 0.3 / 0.7 / 1.0 -> frames 6 / 14 / 20.
    frames: const [6, 14, 20],
    subject: _diff,
    sceneFrames: 40,
    size: _diffSize,
  );
}
