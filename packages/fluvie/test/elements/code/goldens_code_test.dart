// WI-8 (11.1 ACCEPTANCE, D-Highlight/D-CodeReveal/D-Focus/D-Font): the Code
// highlight, typing, focus, and multi-language goldens. Each mounts the real
// `Code` widget through the frame clock. The typing golden maps frames to
// 0.3 / 0.7 / 1.0 of its reveal window. The languages golden renders the same
// subject across dart / python / javascript (the "multiple languages"
// acceptance). The ci variant proves layout on Ahem; the linux variant carries
// the bundled JetBrains Mono glyphs.
@Tags(['golden'])
library;

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart' show Tags;
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/code/code.dart';
import 'package:fluvie/src/elements/code/code_reveal.dart';

import '../../animation/helpers/golden_frame.dart';

const _dart =
    'void main() {\n'
    "  final greeting = 'hi';\n"
    '  for (var i = 0; i < 3; i++) {\n'
    '    print(greeting);\n'
    '  }\n'
    '}';

const _python =
    'def main():\n'
    "    greeting = 'hi'\n"
    '    for i in range(3):\n'
    '        print(greeting)\n';

const _javascript =
    'function main() {\n'
    "  const greeting = 'hi';\n"
    '  for (let i = 0; i < 3; i++) {\n'
    '    console.log(greeting);\n'
    '  }\n'
    '}';

const _codeSize = Size(360, 180);

Widget _highlight() => const Code(_dart, language: 'dart');

Widget _typing() => const Code(
  _dart,
  language: 'dart',
  reveal: CodeReveal.typing(Time.frames(1)),
);

Widget _focus() => const Code(_dart, language: 'dart', focusLines: {4}, highlightLines: {4});

Future<void> main() async {
  await goldenMotionFrames(
    description: 'Code highlights a Dart snippet at the final frame',
    fileName: 'code_highlight',
    frames: const [0],
    subject: _highlight,
    size: _codeSize,
  );
  await goldenMotionFrames(
    description: 'Code types a Dart snippet across its reveal window',
    fileName: 'code_typing',
    // The snippet is ~120 glyphs at 1 frame/glyph; 0.3 / 0.7 / 1.0 ~= 36/84/120.
    frames: const [36, 84, 120],
    subject: _typing,
    sceneFrames: 130,
    size: _codeSize,
  );
  await goldenMotionFrames(
    description: 'Code dims non-focused lines and tints the focused line',
    fileName: 'code_focus',
    frames: const [0],
    subject: _focus,
    size: _codeSize,
  );
  await goldenMotionVariants(
    description: 'Code highlights the same subject across three languages',
    fileName: 'code_languages',
    frame: 0,
    variants: [
      ('dart', () => const Code(_dart, language: 'dart')),
      ('python', () => const Code(_python, language: 'python')),
      ('javascript', () => const Code(_javascript, language: 'javascript')),
    ],
    size: _codeSize,
  );
}
