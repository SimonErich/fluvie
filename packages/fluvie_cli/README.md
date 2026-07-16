# fluvie_cli

The command line for [Fluvie](https://pub.dev/packages/fluvie) compositions. It
scaffolds a project, previews a composition live with hot reload, and renders it
headlessly: it captures frames with `flutter test` (software rendering, no
display needed), then encodes them with FFmpeg into a real video file.

Point it at a `.dart` file and it generates whatever it needs, per invocation, so
there is no app and no harness to maintain.

[![pub package](https://img.shields.io/pub/v/fluvie_cli.svg)](https://pub.dev/packages/fluvie_cli)
[![license: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

## Install

```sh
dart pub global activate fluvie_cli
```

You need Flutter. You do not need FFmpeg: the first render downloads a pinned,
checksum-verified build and caches it. Run `fluvie ffmpeg install` to fetch it
ahead of time, or point `--ffmpeg` / `FLUVIE_FFMPEG` at your own. See
[Managing FFmpeg](https://docs.fluvie.dev/guides/managing-ffmpeg/).

## Start a project

A Fluvie project is a directory holding a composition file, an `assets/` folder,
and a `pubspec.yaml`. No app, no `main.dart`, no capture harness, no registry, no
platform directories. `fluvie init` scaffolds one:

```sh
fluvie init --dir my_reel
cd my_reel
flutter pub get
```

It writes `pubspec.yaml`, `.gitignore`, `lib/example_video.dart`, `assets/.gitkeep`,
and `analysis_options.yaml` (which wires `custom_lint` so the `fluvie_lints`
rules run as you type). It is not interactive and it never runs `flutter create`.
Files that already exist are skipped, so re-running it is safe.

Useful options:

- `--name <name>`: the composition file name, without the extension. Default:
  `example_video`.
- `--dir <project>`: the directory to scaffold into. Default: the working
  directory.
- `--force`: overwrite files that already exist.

A composition file exposes a top-level `Video build()`. That is what `preview`
and `render` call; `--entry <name>` names a different function. See the
[start a project guide](https://docs.fluvie.dev/getting-started/start-a-project/).

## Preview

```sh
fluvie preview ./lib/example_video.dart
```

A live preview with hot reload: edit the composition, save, watch it redraw.

It runs on your desktop by default rather than the browser. A desktop preview
decodes any clip through FFmpeg, while a browser can only decode what WebCodecs
supports. ProRes is not on that list, so a browser default would show a
placeholder for exactly the compositions people care about.

Useful options:

- `-d, --device <device>`: the device to run on (default: this desktop; `chrome`
  for the browser).
- `--entry <name>`: the top-level function returning the `Video`. Default:
  `build`.
- `--project <dir>`: the Fluvie project holding the composition.

The preview app is generated and cached in `~/.cache/fluvie/preview/<hash>/`,
outside your project.

## Render

```sh
fluvie render ./lib/example_video.dart --out video.mp4
```

The CLI generates a capture harness under `<project>/.fluvie/`, captures every
frame with `flutter test` (software rendering, no display needed), then encodes
with FFmpeg.

Useful options:

- `--out <file>`: the output path (required).
- `--entry <name>`: the top-level function returning the `Video`. Default:
  `build`.
- `--format <mp4|gif|imageSequence|transparent>`: the export format.
- `--quality <low|medium|high|max>`: the encode quality.
- `--aspect <reels|square|landscape|portrait45>`: render at another aspect ratio.
- `--poster <time>`: also write a poster frame (for example `1.5s`, `30f`).
- `--frames <n>`: capture only the first N frames (fast draft renders).
- `--cache`: reuse cached frames for a `.dart` target. Off by default, because
  the frame cache keys on the config and the composition key, never on the
  composition itself, so an edited file with the same size and frame count would
  replay stale frames.
- `--keep-temp`, `--verbose`: debugging controls.

Run `fluvie render --help` for the full list.

`fluvie render <key>` still works for a project that keeps a registry-based
capture harness.

## List

```sh
fluvie list
```

Prints the render keys of a project that still uses a registry, one per line.
Pass `--project <dir>` to point at a specific project. A file-based project needs
no keys, so it needs no `list`.

## Generate from a prompt

With the companion [`fluvie_ai`](https://pub.dev/packages/fluvie_ai) package, the
CLI writes a video from natural language and renders it in one step. Set a
provider and key first:

```sh
export FLUVIE_AI_PROVIDER=claude   # or gemini, mistral, ollama
export ANTHROPIC_API_KEY=sk-...

fluvie generate "a 6s vertical title card, dark gradient, fade-in headline" \
  --out promo.mp4 --spec-out promo.fluvie.json
```

Refine a saved spec; on an edit the current frame is sent to a multimodal model:

```sh
fluvie edit promo.fluvie.json "make the headline yellow" --out promo.mp4
```

Render a spec file directly, with no model call:

```sh
fluvie render --spec promo.fluvie.json --out promo.mp4
```

The `.fluvie.json` is the reproducible artifact: re-render it any time to get the
same video. See the
[authoring guide](https://docs.fluvie.dev/guides/ai-and-mcp/).

The package also exports `printVideoSpecJson(Map)`, a public function that
converts a `VideoSpec` to an editable Dart `Video build()` snippet. It is a pure
transformation (no model call, no render) and is `@experimental`. See the
[AI and MCP guide](https://docs.fluvie.dev/guides/ai-and-mcp/).

## How renders run

FFmpeg is always invoked with an argument list, never a shell string, with
bitexact flags on a single thread. Re-rendering the same composition on the same
machine reproduces the same file.

## Documentation

See the Fluvie [exporting guide](https://docs.fluvie.dev/guides/exporting-your-video/).

## License

MIT. See [LICENSE](https://opensource.org/licenses/MIT).
