# Fluvie

You write widgets. Fluvie turns them into a real video file. There is no timeline
to scrub and no frame math: you describe what the video is, and Fluvie computes
when everything happens.

[![pub package](https://img.shields.io/pub/v/fluvie.svg)](https://pub.dev/packages/fluvie)
[![license: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

You import the Fluvie barrel for Fluvie's surface, and Flutter widgets with
`hide Animation` so Fluvie's `Animation` wins:

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
        const Text(
          'Hello, Fluvie',
          style: TextStyle(color: Colors.white, fontSize: 72, fontWeight: FontWeight.bold),
        ).animate([Animation.fadeIn(), Animation.pop()]),
      ],
    ),
  ],
);
```

This is lesson 01, verbatim. Render it to an MP4 with the
[`fluvie_cli`](https://pub.dev/packages/fluvie_cli) headless renderer, or drive
`RenderService` yourself.

## Why Fluvie

- **Declarative.** Compose `Scene`s and elements like any Flutter tree.
- **Deterministic.** The same input renders byte-identical frames every time, so
  caching, golden tests, and batch rendering all work.
- **Complete.** Text, images, video clips, charts, code and terminal scenes,
  diagrams, audio, captions, transitions, effects, templates, and multi-aspect
  export, all on one public API.

## Author as data, or with AI

A video can also be a JSON `VideoSpec`: save it, load it back, and render it. The
companion [`fluvie_ai`](https://pub.dev/packages/fluvie_ai) package writes that
spec from a prompt with a language model, so you can generate a video from
natural language. The spec is deterministic, so the render stays byte-identical.
See the
[authoring guide](https://docs.fluvie.dev/guides/ai-and-mcp/).

## Install

```sh
dart pub add fluvie
```

Rendering needs FFmpeg on your PATH. See the installation guide.

## Documentation

Full guides, the reference, and twelve runnable lessons live at
[docs.fluvie.dev](https://docs.fluvie.dev). Start with getting started, then the
guides.

## License

MIT licensed. See the `LICENSE` file in this package.
