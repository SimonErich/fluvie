// WI-19 (11.4 ACCEPTANCE, D-Markdown): the Markdown rendering, fenced-code
// delegation, and block-reveal goldens. Each mounts the real `Markdown` widget
// through the frame clock. The reveal golden maps frames to 0.3 / 0.7 / 1.0 of
// its block-reveal window. The ci variant proves layout on Ahem; the linux
// variant carries the bundled JetBrains Mono glyphs for the fenced code.
@Tags(['golden'])
library;

import 'package:flutter/widgets.dart' hide Image;
import 'package:flutter_test/flutter_test.dart' show Tags;
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/markdown/markdown.dart';

import '../../animation/helpers/golden_frame.dart';

const _doc =
    '# Release notes\n'
    '\n'
    'Fluvie renders Markdown to widgets, with **bold** and *italic* runs '
    'and inline `code`.\n'
    '\n'
    '- Faster renders\n'
    '- Highlighted code blocks\n'
    '\n'
    '> Determinism is the headline.\n';

const _fenced =
    '# Example\n'
    '\n'
    'A fenced block renders as a highlighted `Code`:\n'
    '\n'
    '```dart\n'
    'void main() {\n'
    "  print('hi');\n"
    '}\n'
    '```\n';

const _revealDoc = '# One\n\nTwo\n\nThree\n\nFour\n';

const _mdSize = Size(420, 340);

Widget _render() => const Markdown(_doc);

Widget _fencedRender() => const Markdown(_fenced);

Widget _revealRender() => const Markdown(_revealDoc, reveal: Time.frames(40));

Future<void> main() async {
  await goldenMotionFrames(
    description: 'Markdown renders a heading, list, blockquote, and inline styles',
    fileName: 'markdown_render',
    frames: const [0],
    subject: _render,
    size: _mdSize,
  );
  await goldenMotionFrames(
    description: 'Markdown renders a fenced block as a highlighted Code',
    fileName: 'markdown_fenced_code',
    frames: const [0],
    subject: _fencedRender,
    size: _mdSize,
  );
  await goldenMotionFrames(
    description: 'Markdown reveals its blocks one after another',
    // The reveal window is 40 frames; 0.3 / 0.7 / 1.0 ~= 12 / 28 / 40.
    frames: const [12, 28, 40],
    fileName: 'markdown_reveal',
    subject: _revealRender,
    size: _mdSize,
  );
}
