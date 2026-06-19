// Mermaid/WebView/Html are @experimental for 1.0 (their live headless-Chrome
// transport ships disabled). This lesson uses the offline fake snapshot
// service, so the experimental-use warning is expected and silenced here.
// ignore_for_file: experimental_member_use

import 'package:flutter/material.dart' hide Animation, Image;
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/lessons/lesson.dart';

const _label = TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w600);

/// The flow the Mermaid scene draws: a small pipeline diagram.
const _flow =
    'graph LR;\n'
    '  Source[Mermaid source] --> Layout[Chromium layout];\n'
    '  Layout --> Raster[in-process raster];\n'
    '  Raster --> Frame[every frame];';

/// The Markdown the doc scene renders, reusing the `Markdown` element.
const _notes =
    '# Diagrams and pages\n\n'
    'Every snapshot is **rasterized once** before frame 0.\n\n'
    '- `Mermaid` lays out in Chromium, rasterizes in process\n'
    '- `WebView` and `Html` screenshot at a fixed viewport\n'
    '- the frame loop only paints the cached still';

/// The inline HTML the browser-framed scene captures (no network, no file).
const _page =
    '<html><body style="font-family: sans-serif; padding: 24px">\n'
    '<h1>fluvie.dev</h1>\n'
    '<p>A page captured to a deterministic raster.</p>\n'
    '</body></html>';

/// The fixed box the page is laid out and screenshotted in.
const _viewport = SnapshotViewport(width: 720, height: 405);

/// Lesson 09 — diagrams and web pages: a Mermaid diagram that
/// reveals over its window, a Markdown explainer, and an inline web page framed
/// in a browser. Every snapshot rasterizes once before the frame loop, so the
/// lesson renders offline and deterministically from a fixture raster.
const lesson09DiagramsAndWebviews = Lesson(
  id: '09_diagrams_and_webviews',
  title: 'Diagrams and web pages',
  intro:
      'A Mermaid diagram drawing its edges in, a Markdown explainer, and an '
      'inline web page framed in a browser. Each snapshot is rasterized once '
      'before frame 0 and painted as a still, so the whole lesson renders '
      'offline with no Chromium and no network. The reveal is intrinsic to '
      'Mermaid; .animate() only adds the outer slide and fade.',
  video: lesson09Video,
);

/// Builds the lesson 09 composition: a three-scene, 9 second 16:9 explainer.
///
/// Each scene paints a pre-rasterized snapshot: the [Mermaid] diagram reveals
/// over its own window ([MermaidReveal.drawEdges]), the [Markdown] renders the
/// explainer, and the [Html] page sits inside a [DeviceFrame.browser].
/// The example resolves every snapshot through its bundled offline fixture
/// service before the frame loop, so the diagram and the
/// page are present from the first frame with no async pop-in.
Video lesson09Video() {
  return Video(
    size: VideoSize.hd,
    poster: 6.seconds,
    transition: Transition.crossFade(0.5.seconds),
    scenes: [
      _diagramScene(),
      _notesScene(),
      _browserScene(),
    ],
  );
}

/// Scene 1: the Mermaid pipeline diagram drawing its edges in.
Scene _diagramScene() => Scene(
  duration: 3.seconds,
  background: Background.gradient(const [Color(0xFF0B1F2A), Color(0xFF15323F)]),
  children: [
    const Positioned(top: 48, left: 64, child: Text('How a snapshot renders', style: _label)),
    Center(
      child: SizedBox(
        width: 1280,
        height: 600,
        // #docregion mermaid
        child: const Mermaid(
          _flow,
          theme: MermaidTheme.dark(),
          reveal: MermaidReveal.drawEdges(Time.seconds(1)),
        ).animate([Animation.slideFade()]),
        // #enddocregion mermaid
      ),
    ),
  ],
);

/// Scene 2: the Markdown explainer.
Scene _notesScene() => Scene(
  duration: 3.seconds,
  background: Background.color(const Color(0xFF11161C)),
  children: [
    Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(96, 64, 96, 64),
        // #docregion markdown
        child: const Markdown(
          _notes,
          reveal: Time.seconds(1),
        ).animate([Animation.fadeIn()]),
        // #enddocregion markdown
      ),
    ),
  ],
);

/// Scene 3: the inline web page captured and framed in a browser window.
Scene _browserScene() => Scene(
  duration: 3.seconds,
  background: Background.color(const Color(0xFF0B1F2A)),
  children: [
    const Positioned(top: 48, left: 64, child: Text('A page in a frame', style: _label)),
    Center(
      child: SizedBox(
        width: 1280,
        height: 760,
        // #docregion browser
        child: const DeviceFrame.browser(
          url: 'https://fluvie.dev',
          child: SizedBox.expand(child: Html(_page, viewport: _viewport)),
        ).animate([Animation.slideFade()]),
        // #enddocregion browser
      ),
    ),
  ],
);
