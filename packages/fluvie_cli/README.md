# fluvie_cli

The headless renderer for [Fluvie](https://pub.dev/packages/fluvie) compositions.
It captures frames with `flutter test` (software rendering, no display needed),
then encodes them with FFmpeg into a real video file.

[![pub package](https://img.shields.io/pub/v/fluvie_cli.svg)](https://pub.dev/packages/fluvie_cli)
[![license: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

## Install

```sh
dart pub global activate fluvie_cli
```

You also need FFmpeg on your PATH.

## Start a project

`fluvie init` gets you going. Inside an existing Flutter project it drops a
starter composition (real Flutter widget code) and wires a render harness so
`fluvie render` works; run it outside a Flutter project and it scaffolds a
minimal, runnable Fluvie project with `flutter create`.

```sh
fluvie init            # prompts for a location/name; press Enter for the default
```

It is the one interactive command. Run it without prompts in CI or scripts:

```sh
fluvie init --yes                          # accept every default
fluvie init --name intro --path lib/videos/intro.dart --yes
fluvie init --dir my_reel --yes            # scaffold a new project (no Flutter project here)
```

Useful options:

- `--name <name>`: the composition name (the render key and file name).
- `--path <file>`: where to write the composition in an existing project.
- `--dir <project>`: the directory for a new project.
- `--no-render`: skip the render harness in an existing project.
- `--force`: overwrite files that already exist.
- `--yes`: accept defaults; do not prompt.

After it runs, `flutter pub get`, then `flutter run` to preview and
`fluvie render <name> --out <name>.mp4` to render. See the
[start a project guide](https://docs.fluvie.dev/getting-started/start-a-project/).

## Render

```sh
fluvie render <composition> --out video.mp4
```

Useful options:

- `--out <file>`: the output path (required).
- `--format <mp4|gif|imageSequence|transparent>`: the export format.
- `--quality <low|medium|high|max>`: the encode quality.
- `--aspect <...>`: render a composition at another aspect ratio.
- `--poster <time>`: also write a poster frame (for example `1.5s`, `30f`).
- `--frames <n>`: capture only the first N frames (fast draft renders).
- `--no-cache`, `--keep-temp`, `--verbose`: caching and debugging controls.

Run `fluvie render --help` for the full list.

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
