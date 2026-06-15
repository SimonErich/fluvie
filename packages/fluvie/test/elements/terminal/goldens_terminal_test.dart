// WI-15 (11.3 ACCEPTANCE, D-LineModel/D-Chrome/D-Font): the Terminal sequence
// and chrome goldens. Each mounts the real `Terminal` widget through the frame
// clock. The sequence golden probes frames where line 0 is mid-typing (caret
// visible) and where line 1 has streamed in, proving the prompt + caret + output
// render correctly. The chrome golden shows the macOS window bar with its dots.
// The ci variant proves layout on Ahem; the linux variant carries the bundled
// JetBrains Mono glyphs.
@Tags(['golden'])
library;

import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart' show Tags;
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/terminal/terminal.dart';
import 'package:fluvie/src/elements/terminal/terminal_chrome.dart';
import 'package:fluvie/src/elements/terminal/terminal_line.dart';

import '../../animation/helpers/golden_frame.dart';

const _lines = [
  TerminalLine.cmd('npm install'),
  TerminalLine.out('added 120 packages in 3s'),
  TerminalLine.cmd('npm test'),
  TerminalLine.out('all 42 tests passed'),
];

const _terminalSize = Size(360, 180);

Widget _terminal() => const Terminal(lines: _lines, lineGap: Time.frames(16));

Widget _chromeTerminal() => const Terminal(
  chrome: TerminalChrome.macos(title: 'zsh'),
  lines: _lines,
  lineGap: Time.frames(16),
);

Future<void> main() async {
  await goldenMotionFrames(
    description: 'Terminal types a command then streams its output, then a second pair',
    fileName: 'terminal_sequence',
    // frame 4: line 0 mid-typing, caret lit (period 16, first half).
    // frame 60: line 0 settled, line 1 streamed in.
    // frame 200: the full four-line session settled.
    frames: const [4, 60, 200],
    subject: _terminal,
    sceneFrames: 240,
    size: _terminalSize,
  );
  await goldenMotionFrames(
    description: 'Terminal paints the macOS window chrome bar with its traffic-light dots',
    fileName: 'terminal_chrome',
    frames: const [200],
    subject: _chromeTerminal,
    sceneFrames: 240,
    size: _terminalSize,
  );
}
