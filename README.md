<p align="center">
  <img src="documentation/fluvie_logo.svg" alt="Fluvie" width="160">
</p>

<h1 align="center">Fluvie</h1>

<p align="center"><strong>You write widgets. Fluvie shoots the film.</strong></p>

<p align="center">
  <a href="https://pub.dev/packages/fluvie"><img src="https://img.shields.io/pub/v/fluvie.svg" alt="pub package"></a>
  <a href="https://github.com/SimonErich/fluvie/actions/workflows/ci.yaml"><img src="https://github.com/SimonErich/fluvie/actions/workflows/ci.yaml/badge.svg" alt="CI"></a>
  <a href="https://codecov.io/gh/SimonErich/fluvie"><img src="https://codecov.io/gh/SimonErich/fluvie/branch/main/graph/badge.svg" alt="coverage"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-purple.svg" alt="License: MIT"></a>
  <a href="https://melos.invertase.dev"><img src="https://img.shields.io/badge/maintained%20with-melos-f700ff.svg" alt="maintained with melos"></a>
</p>

Fluvie renders a declarative Flutter tree to a real video file (MP4 via FFmpeg).
You describe what the video is. Fluvie works out when everything happens, frame by
frame. Think of it as a tiny film studio that already speaks Flutter: you direct,
Fluvie handles continuity, and FFmpeg runs the projector.

No timeline to scrub. No keyframe spreadsheet. No 2am debugging because frame 412
is one pixel off.

- **Declarative.** Compose `Scene`s and elements like any Flutter screen.
- **Deterministic.** The same input renders byte-identical frames, every time. Caching, golden tests, and batch rendering just work.
- **Headless.** Render from the CLI, an HTTP API, or an MCP server. No display needed.
- **Conversational.** Ask for a video in plain language and get a deterministic spec back.

## Quick start

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

Roll camera from the command line:

```sh
dart pub global activate fluvie_cli
fluvie render hello --out hello.mp4
```

That is lesson 01. The [getting started guide](https://docs.fluvie.dev/getting-started/your-first-video/)
wires the render key in one step and explains the FFmpeg setup.

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

Twelve runnable lessons live in [`example/`](example).

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
