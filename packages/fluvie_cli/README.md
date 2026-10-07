# fluvie_cli

The command line for [Fluvie](https://pub.dev/packages/fluvie) compositions. It
scaffolds a project, previews a composition live with hot reload, and renders it
headlessly: it captures frames with `flutter test` (software rendering, no
display needed), then encodes them with FFmpeg into a real video file.

Point it at a `.dart` file and it prepares the preview and render host outside
your project. You maintain ordinary Flutter composition code and assets.

[![pub package](https://img.shields.io/pub/v/fluvie_cli.svg)](https://pub.dev/packages/fluvie_cli)
[![license: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

## Install

```sh
dart pub global activate fluvie_cli
```

For unpublished changes, run `dart tool/activate_cli.dart` from the Fluvie
repository root. It activates the CLI from a persistent external host with local
package sources, without resolving unrelated workspace apps. `--prepare-only`
prints that host's path; `--install-dir <directory>` selects its external parent;
`--offline` reuses an already resolved dependency graph. In the consumer project,
run `fluvie init` followed by `flutter pub get`: it discovers the source checkout
automatically, including the Windows copy fallback. `--fluvie-path` chooses
another checkout explicitly. Rerun the installer after dependency changes or
copied CLI source changes; linked package source stays live.

You need Flutter >=3.44 with Dart >=3.12. Native media tools are automatic: the
first render or media preview installs a pinned, checksum-verified FFmpeg/ffprobe
pair in a user cache. Run `fluvie ffmpeg install` to warm it, or use an explicit
pair through `--ffmpeg` and `--ffprobe`. See
[Managing FFmpeg](https://docs.fluvie.dev/guides/managing-ffmpeg/).

## Start a project

A Fluvie project is a directory holding a composition file, an `assets/` folder,
and a `pubspec.yaml`. It can be a fresh `flutter create` app or a composition-only
project. `fluvie init` merges or scaffolds the authoring setup:

```sh
fluvie init --dir my_reel
cd my_reel
flutter pub get
```

It writes `pubspec.yaml`, `.gitignore`, `lib/example_video.dart`, `assets/.gitkeep`,
and normal Flutter analysis settings. It is not interactive and it never runs
`flutter create`. In an existing Flutter project it merges the required setup
and preserves your app and unrelated dependencies. Fluvie custom lints and AI
packages are optional.

Useful options:

- `--name <name>`: the composition file name, without the extension. Default:
  `example_video`.
- `--dir <project>`: the directory to scaffold into. Default: the working
  directory.
- `--force`: overwrite generated starter files that already exist.
- `--with-ai`, `--with-lints`: add optional AI authoring or custom Fluvie lints.
- `--fluvie-path <checkout>`: use a local Fluvie checkout while developing it.

A composition file exposes a top-level `Video build()`. That is what `preview`
and `render` call; `--entry <name>` names a different function. See the
[start a project guide](https://docs.fluvie.dev/getting-started/start-a-project/).

## Preview

```sh
fluvie preview ./lib/example_video.dart
```

A live preview with hot reload: edit the composition, save, watch it redraw.

Preview prints a local browser URL by default and supplies an authenticated
native media bridge for clip decoding and audio. Pass `-d chrome` to open
Chrome, or select a Flutter desktop device. Enable sound through the player's
control; browser audio needs a user gesture.

Useful options:

- `-d, --device <device>`: `web-server` by default; `chrome` opens Chrome,
  and `linux`, `macos`, or `windows` selects the matching desktop device.
- `--json`: stream structured preview URL and reload events.
- `--toolchain managed|system`, `--ffmpeg`, `--ffprobe`, `--no-download`:
  select or warm native tools explicitly.
- `--entry <name>`: the top-level function returning the `Video`. Default:
  `build`.
- `--project <dir>`: the Fluvie project holding the composition.

The preview app is generated and cached in `~/.cache/fluvie/preview/<hash>/`,
outside your project.

## Render

```sh
fluvie render ./lib/example_video.dart
```

The CLI prepares its harness and rendering dependencies in an external user
cache, captures every frame with Flutter, then encodes with FFmpeg. Output
defaults to `build/fluvie/example_video.mp4`; authored size, FPS, duration, export
mode, quality, and poster come from the `Video`.

Useful options:

- `--out <file>`: override the automatic output path.
- `--entry <name>`: the top-level function returning the `Video`. Default:
  `build`.
- `--format <mp4|gif|imageSequence|transparent>`: the export format.
- `--quality <low|medium|high|max>`: the encode quality.
- `--aspect <reels|square|landscape|portrait45>`: render at another aspect ratio.
- `--poster <time>`: also write a poster frame (for example `1.5s`, `30f`).
- `--frames <n>`: capture only the first N frames (fast draft renders).
- `--no-cache`: capture fresh frames. Managed file renders fingerprint local
  source/dependencies, assets/fonts/shaders, resolution, SDK, tools, and options
  before reusing frames. Bypass cache for changing external/network/generator
  resources outside those inputs.
- `--cache-key <identity>`: include a caller-owned version/hash for runtime or
  external inputs. Change it when those inputs change; it does not track them
  automatically. Required to enable cache for source outside the selected project.
- `--machine`: JSON-line progress and final artifact data. A retained
  `<output stem>.render.json` receipt records hashed inputs, tools, settings,
  capture facts, actual encoded media/probe data, authored poster identity, and
  output SHA-256. Encoded facts are compared to resolved intent before the compact
  final artifact event. Failed verification retains a `.failed.render.json` receipt.
- `--renderer`, `--renderer-entry`, `--harness`: optional custom render hosts.
- `--keep-temp`, `--verbose`: debugging controls.

Run `fluvie render --help` for the full list.

`fluvie render <key>` still works for a project that keeps a registry-based
capture harness.

## Inspect and validate

```sh
fluvie doctor --json
fluvie assets ./assets --json
fluvie validate ./lib/example_video.dart --json
fluvie inspect ./lib/example_video.dart --json
fluvie frame ./lib/example_video.dart --frame 30 --json
```

`doctor` is read-only and reports actionable setup checks. `assets` inventories
nested files, media facts, bounded story notes, and font declarations without
semantic AI analysis. Inventory reports missing native tools without downloading;
`--download-tools` explicitly warms them. `validate` checks the original Dart source and relative
imports without executing it. `inspect` compiles and prepares the real
composition to report its resolved timeline; `frame` captures a reviewable PNG.

```sh
fluvie review ./lib/example_video.dart --determinism --json
fluvie review ./lib/example_video.dart --render --strict-decode --json
```

`review` combines static diagnostics, mounted inspection and representative
captures. `--determinism` compares selected pictures in different seek orders;
it checks samples, not every possible frame. `--render` verifies encoded facts
against render intent, and `--strict-decode` adds a complete decode. See
[Review a video](https://docs.fluvie.dev/guides/reviewing-a-video/).


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
  --spec-out promo.fluvie.json --dart-out lib/promo.dart
```

Local `assets/` files supply factual source keys and media metadata automatically.
Use `--assets <directory>` for another root. Story notes are explicit inputs:
`--context "<text>"` or repeatable `--context-file assets/story.txt`. At most four
files contribute 8,192 bytes each, and total context is bounded to 64 KiB. The
package does not infer image/video contents from filenames or run semantic asset
analysis. A coding assistant can inspect the actual media through its own tools.


Generation always writes Dart before rendering. With no `--dart-out`, it uses
`lib/generated_video.dart` or the next free numbered name. Edit Dart directly to
preserve untouched code, custom widgets, imports and comments:

```sh
fluvie edit lib/promo.dart "make the headline yellow" --no-render
```

The command validates a sibling candidate and its mounted composition before
replacing the original, then retains the original as `<file>.fluvie.bak`.
Validation failure leaves the source unchanged. You can also refine a saved spec;
multimodal spec edits can include a current rendered frame:

```sh
fluvie edit promo.fluvie.json "make the headline yellow" --dart-out lib/promo.dart
```

Render a spec file directly, with no model call:

```sh
fluvie render --spec promo.fluvie.json
```

The spec and generated Dart preserve the authored story and timing.
Output defaults to `build/fluvie/`; `--out` overrides it. Use `--no-render` to
write a spec and Dart without capturing frames. See the
[authoring guide](https://docs.fluvie.dev/guides/ai-and-mcp/).

For source-bound observations and transcripts, use `assets --catalog-out`.
`--contact-sheets` also generates timestamped local pictures. `generate` and
`edit` accept `--catalog`; `--image-evidence` explicitly attaches up to four
verified contact sheets to a vision provider. Catalog creation calls no model.
See [Asset evidence](https://docs.fluvie.dev/guides/asset-evidence/) for the file
schema, certainty and provenance rules.

The package also exports `printVideoSpecJson(Map)`, a public function that
converts a `VideoSpec` to an editable Dart `Video build()` snippet. It is a pure
transformation (no model call, no render) and is `@experimental`. See the
[AI and MCP guide](https://docs.fluvie.dev/guides/ai-and-mcp/).

## How renders run

FFmpeg is invoked with an argument list, never a shell string. Authored code and
timing can be replayed; output bytes also depend on the Flutter engine, encoding
settings, platform, and selected toolchain.

## Documentation

See the Fluvie [exporting guide](https://docs.fluvie.dev/guides/exporting-your-video/).

## License

MIT. See [LICENSE](https://opensource.org/licenses/MIT).

## Offline authoring documentation

Run `fluvie docs --context` to print a focused guide for your coding assistant.
The CLI and MCP server ship the same versioned documentation corpus; they work
without a repository checkout or network access. The full public corpus is also
available as `llms.txt` and `llms-full.txt` on the docs site.

## Inspect, measure and replay

`fluvie workspace lib/my_video.dart` opens one native frame/review/export session.
`fluvie session session.json frame --frame 30` lets an assistant use that same
engine. Results carry source revision, backend, startup and request timings.
See the [workspace guide](https://docs.fluvie.dev/guides/authoring-workspace/).

`fluvie review lib/my_video.dart --render` writes an offline review page and
measured text/audio findings. `--strict-quality` fails on findings not explicitly
allowed with `--allow-quality`.

`fluvie bundle create lib/my_video.dart --out project.zip` preserves source,
resources and resolved dependencies. `bundle inspect`, `bundle unpack` and
`bundle replay` verify and restore it. Replay enforces the copied lockfile.
See [portable projects](https://docs.fluvie.dev/guides/portable-projects/).

`fluvie benchmark suite.json --project fixture --provider gemini --model <model>`
retains real model prompts/replies, Dart, preservation checks and render evidence.
See [authoring benchmarks](https://docs.fluvie.dev/guides/authoring-benchmarks/).
