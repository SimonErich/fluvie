<p align="center">
  <img src="documentation/fluvie_logo.svg" alt="Fluvie" width="360">
</p>

<p align="center"><strong>You write widgets. Fluvie shoots the film.</strong></p>

<p align="center">
  <a href="https://pub.dev/packages/fluvie"><img src="https://img.shields.io/pub/v/fluvie.svg" alt="pub package"></a>
  <a href="https://github.com/SimonErich/fluvie/actions/workflows/ci.yaml"><img src="https://github.com/SimonErich/fluvie/actions/workflows/ci.yaml/badge.svg" alt="CI"></a>
  <a href="https://codecov.io/gh/SimonErich/fluvie"><img src="https://codecov.io/gh/SimonErich/fluvie/branch/main/graph/badge.svg" alt="coverage"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-purple.svg" alt="License: MIT"></a>
  <a href="https://melos.invertase.dev"><img src="https://img.shields.io/badge/maintained%20with-melos-f700ff.svg" alt="maintained with melos"></a>
</p>

**Fluvie is a Flutter package that turns widget code into real video files.** You
build a video the way you build a screen, with `Scene`s and the Flutter widgets
you already know, you say how long each thing lasts, and Fluvie renders every
frame and encodes it into an MP4 (or a GIF, or an image sequence) with FFmpeg. No
video editor, no manual timeline, no After Effects.

Think of it as a tiny film studio that already speaks Flutter: you direct, Fluvie
handles continuity, and FFmpeg runs the projector. No timeline to scrub, no
keyframe spreadsheet, no 2am debugging because frame 412 is one pixel off.

- **Declarative.** Compose `Scene`s and elements like any Flutter screen.
- **Deterministic.** The same input renders byte-identical frames, every time. Caching, golden tests, and batch rendering just work.
- **Headless.** Render from the CLI, an HTTP API, or an MCP server. No display needed.
- **Conversational.** Ask for a video in plain language and get a deterministic spec back.

## Quick start

This is lesson 01, in full. Roughly 30 lines of widgets becomes a 4 second clip:

```dart
import 'package:flutter/material.dart' hide Animation;
import 'package:fluvie/fluvie.dart';

Video helloVideo() => Video(
  size: VideoSize.square,
  poster: 1.seconds,
  scenes: [
    Scene(
      duration: 4.seconds,
      background: Background.gradient(const [Color(0xFF1A2980), Color(0xFF26D0CE)]),
      children: [
        const Text('Hello, Fluvie', style: TextStyle(color: Colors.white, fontSize: 72))
            .animate([Animation.fadeIn(), Animation.pop()]),
      ],
    ),
  ],
);
```

```sh
dart pub global activate fluvie_cli
fluvie render hello --out hello.mp4
```

<p align="center">
  <img src="documentation/media/quickstart.gif" alt="The Hello, Fluvie clip Fluvie renders from the code above" width="360">
</p>

The [getting started guide](https://docs.fluvie.dev/getting-started/your-first-video/)
wires the render key in one step and explains the FFmpeg setup. Full source:
[`example/lib/lessons/01_hello_video.dart`](example/lib/lessons/01_hello_video.dart).

## See what it can do

The snippets below are trimmed to the shape of the thing. Each links to its full,
runnable lesson.

### Charts that reveal themselves

A counter headline, then a bar, a line, and a donut, each animating in from its
own data. One theme colors them all.

```dart
Video chartsVideo() => Video(
  size: VideoSize.square,
  scenes: [
    Scene(duration: 3.seconds, children: [
      Chart.bar(data: {'Q1': 42, 'Q2': 58, 'Q3': 71, 'Q4': 96}, growIn: 1.seconds),
    ]),
    Scene(duration: 3.seconds, children: [
      Chart.line(data: {'W1': 12, 'W2': 26, /* ... */}, drawIn: 1.5.seconds),
    ]),
    Scene(duration: 2500.ms, children: [
      Chart.donut(data: {'Search': 48, 'Social': 27, /* ... */}, sweepIn: 1.seconds),
    ]),
  ],
);
```

<p align="center">
  <img src="documentation/media/charts.gif" alt="A bar, line, and donut chart animating in" width="360">
</p>

Full source: [`example/lib/lessons/07_charts.dart`](example/lib/lessons/07_charts.dart).

### Layers and scenes, set to a beat

Several scenes play one after another with a cross-fade. Each scene stacks
layers: a full-frame effect under the content, a chip that pops on the music
beat, captions over the top.

```dart
Video reel() => Video(
  size: VideoSize.reels, // 9:16
  transition: Transition.crossFade(0.4.seconds),
  audio: [Audio.music('beat.wav', track: music)],
  captions: const Captions.fromSrt('captions.srt', style: CaptionStyle.tikTok()),
  scenes: [
    Scene(children: [
      Box(/* ... */).animate([Animation.pop(at: Trigger.beat(track: music))]),
      const Text('On the beat').animate([Animation.fadeIn()]),
    ]),
    Scene(children: [
      const ColoredBox(/* ... */).animate([Animation.grain(0.12)]), // an effect layer
      Counter(to: 12000, duration: 1500.ms),
    ]),
    Scene.centered(child: /* ... outro ... */),
  ],
);
```

<p align="center">
  <img src="documentation/media/kitchensink.gif" alt="A vertical reel with layered scenes, a beat-synced pop, captions, and an outro" width="240">
</p>

Full source: [`example/lib/lessons/12_the_kitchen_sink.dart`](example/lib/lessons/12_the_kitchen_sink.dart).

## Examples

Twelve runnable lessons live in [`example/lib/lessons/`](example/lib/lessons),
from "Hello, Fluvie" to the kitchen sink. Run the gallery with `flutter run` from
the repo root, or try it in the browser at [demo.fluvie.dev](https://demo.fluvie.dev).

## Packages

**Most people only need `fluvie`.** The rest are there when you want to render in
CI, on a server, or from an AI assistant.

| Package | Role | pub.dev |
| --- | --- | --- |
| [`fluvie`](packages/fluvie) | The library. Describe a video, render an MP4. | [![pub](https://img.shields.io/pub/v/fluvie.svg)](https://pub.dev/packages/fluvie) |
| [`fluvie_cli`](packages/fluvie_cli) | Headless renderer. Capture with `flutter test`, encode with FFmpeg. | [![pub](https://img.shields.io/pub/v/fluvie_cli.svg)](https://pub.dev/packages/fluvie_cli) |
| [`fluvie_lints`](packages/fluvie_lints) | Lint rules that catch timing and determinism mistakes. | [![pub](https://img.shields.io/pub/v/fluvie_lints.svg)](https://pub.dev/packages/fluvie_lints) |
| [`fluvie_ai`](packages/fluvie_ai) | Author a video from a prompt. A model writes a deterministic spec. | [![pub](https://img.shields.io/pub/v/fluvie_ai.svg)](https://pub.dev/packages/fluvie_ai) |
| [`fluvie_api`](packages/fluvie_api) | HTTP render server (local or S3) plus a web-safe client. | [![pub](https://img.shields.io/pub/v/fluvie_api.svg)](https://pub.dev/packages/fluvie_api) |
| [`fluvie_mcp`](packages/fluvie_mcp) | MCP server. Let Claude (or any assistant) author and render for you. | [![pub](https://img.shields.io/pub/v/fluvie_mcp.svg)](https://pub.dev/packages/fluvie_mcp) |

## The ecosystem

The library is the whole show. These hosted pieces are the lobby, the trailers,
and the box office.

| Where | What you get |
| --- | --- |
| [fluvie.dev](https://fluvie.dev) | The front of house: what Fluvie is, in one screen. |
| [docs.fluvie.dev](https://docs.fluvie.dev) | The manual: getting started, guides, a cookbook, and the full reference. |
| [demo.fluvie.dev](https://demo.fluvie.dev) | The screening room: try Fluvie live in the browser and render a clip. |
| [mcp.fluvie.dev](https://mcp.fluvie.dev) | The hosted MCP server, so an AI assistant can make videos with Fluvie. |

## Documentation

Start at [docs.fluvie.dev](https://docs.fluvie.dev):

- **[Getting started](https://docs.fluvie.dev/getting-started/installation/)**: install, your first video, the core ideas.
- **[Guides](https://docs.fluvie.dev/guides/animating-elements/)**: animation, audio, charts, code scenes, theming, exporting.
- **[Cookbook](https://docs.fluvie.dev/cookbook/)**: short, copy-paste recipes for one task each.
- **[AI and MCP](https://docs.fluvie.dev/guides/ai-and-mcp/)**: author from a prompt, run it locally, or point Claude at it.
- **[Reference](https://docs.fluvie.dev/reference/cheatsheet/)**: the whole public surface on one page.

## What goes in a video

Everything you can paint with Flutter, plus the things a video needs:

| Kind | What you get |
| --- | --- |
| Text | `Text`, `Typewriter`, `Counter`, `Markdown` |
| Code | `Code`, `CodeReveal` (animated diffs), `Terminal` |
| Media | `Image`, `Clip` (embedded video), `Snapshot`, `DeviceFrame` |
| Data | `Chart` (bar, line, area, pie, donut, scatter), `Bars` |
| Diagrams and web | `Mermaid`, `WebView`, `Html` |
| Annotations | `Shape`, `Arrow`, `Connector`, `Callout`, `Spotlight`, `LowerThird`, `TitleCard` |
| Motion and effects | 60+ animation presets, `Stagger`, `Camera`, shaders, particles, grain |
| Audio | `Audio` (music and sfx), beat detection, `Captions` (SRT and VTT) |
| Look | `Background` (color, gradient, image), `FluvieTheme`, multi-aspect export |

## What you can make with it

| Use case | For example |
| --- | --- |
| Product demos | feature walkthroughs, onboarding clips, changelog videos |
| Social reels | 9:16 vertical shorts for TikTok, Reels, and Shorts |
| Explainers | tutorials and concept animations |
| Data stories | stat highlight reels and animated reports |
| Developer content | code walkthroughs, terminal demos, release notes |
| Branding | title cards, intros, and lower thirds |

## Contributing

Pull up a chair. Read [CONTRIBUTING.md](CONTRIBUTING.md), install the hooks once,
and keep the gate green:

```sh
dart pub get && dart run melos bootstrap
bash .githooks/install.sh
CI=true dart run melos run gate
```

## Community

- [Discussions](https://github.com/SimonErich/fluvie/discussions): questions and ideas.
- [Issues](https://github.com/SimonErich/fluvie/issues): bugs and feature requests.
- [Code of Conduct](CODE_OF_CONDUCT.md) and [Security policy](SECURITY.md).

## License

[MIT](LICENSE) © 2026 Simon Auer.
