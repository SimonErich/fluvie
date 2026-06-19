import 'package:flutter/material.dart' hide Animation, Image;
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/lessons/lesson.dart';

const _label = TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w600);

/// The snippet the Code scene types out, then focuses on its loop body.
const _snippet =
    'Video build() {\n'
    '  return Video(\n'
    '    size: VideoSize.square,\n'
    '    scenes: [\n'
    '      Scene(children: [Text(greeting)]),\n'
    '    ],\n'
    '  );\n'
    '}';

/// Lesson 08 — a developer-video intro: a title card, a `Code`
/// scene that types itself out and focuses its key lines, and a `Terminal`
/// scene that runs a command and streams its output.
const lesson08CodeDocIntro = Lesson(
  id: '08_code_doc_intro',
  title: 'Code and terminal',
  intro:
      'A title card, a Code block that types itself out and then focuses its '
      'key lines, and a Terminal that runs a command and streams the output. '
      'The reveal is intrinsic to each element; .animate() only adds the outer '
      'motion. The same bundled mono font ships to every render.',
  video: lesson08Video,
);

/// Builds the lesson 08 composition: a three-scene, 9 second square explainer.
///
/// The Code reveal (`CodeReveal.typing`) and the Terminal sequence are both
/// intrinsic — they resolve against their own scene windows, so the typing and
/// the command run play for as long as the scene lasts. `.animate()` only adds
/// the outer slide and fade. A [Captions.words] track narrates the three scenes
/// as a scene-spanning overlay; the cues are parsed before frame 0, never read
/// mid-frame.
Video lesson08Video() {
  return Video(
    size: VideoSize.square,
    poster: 4.seconds,
    transition: Transition.crossFade(0.5.seconds),
    // #docregion captions
    captions: Captions.words(
      const [
        CaptionWord('Type', at: Time.seconds(2.4)),
        CaptionWord('it', at: Time.seconds(3)),
        CaptionWord('out,', at: Time.seconds(3.4)),
        CaptionWord('then', at: Time.seconds(4.2)),
        CaptionWord('run', at: Time.seconds(6.4)),
        CaptionWord('it.', at: Time.seconds(7)),
      ],
      style: const CaptionStyle.tikTok(),
    ),
    // #enddocregion captions
    scenes: [
      _titleScene(),
      _codeScene(),
      _terminalScene(),
    ],
  );
}

/// Scene 1: the title card that opens the explainer.
///
/// [TitleCard] centers a headline and a subtitle and fades them up over its
/// [TitleCard.reveal] window, so the opener needs no hand-built Column or
/// per-line animation.
Scene _titleScene() => Scene(
  duration: 2.seconds,
  background: Background.gradient(const [Color(0xFF0B1F2A), Color(0xFF15323F)]),
  children: const [
    // #docregion title
    TitleCard(
      title: 'Code, on screen',
      subtitle: 'typed, highlighted, focused',
      reveal: Time.seconds(0.6),
    ),
    // #enddocregion title
  ],
);

/// Scene 2: the code block typing itself in, then focusing the loop body.
Scene _codeScene() => Scene(
  duration: 4.seconds,
  background: Background.color(const Color(0xFF1E1E1E)),
  children: [
    const Positioned(top: 64, left: 64, child: Text('Type it out', style: _label)),
    Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(64, 120, 64, 64),
        // #docregion code
        child: Code(
          _snippet,
          language: 'dart',
          reveal: CodeReveal.typing(1.frames),
          focusLines: const {5},
          highlightLines: const {5},
        ).animate([Animation.slideFade()]),
        // #enddocregion code
      ),
    ),
  ],
);

/// Scene 3: the terminal running a command and streaming its output.
Scene _terminalScene() => Scene(
  duration: 3.seconds,
  background: Background.color(const Color(0xFF11161C)),
  children: [
    const Positioned(top: 64, left: 64, child: Text('Run it', style: _label)),
    Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(64, 120, 64, 64),
        // #docregion terminal
        child: const Terminal(
          chrome: TerminalChrome.macos(title: 'zsh'),
          lines: [
            TerminalLine.cmd('dart run fluvie render hello'),
            TerminalLine.out('Rendering 270 frames...'),
            TerminalLine.out('Wrote hello.mp4 (9.0s, 1080x1080)'),
          ],
        ).animate([Animation.slideFade()]),
        // #enddocregion terminal
      ),
    ),
  ],
);
