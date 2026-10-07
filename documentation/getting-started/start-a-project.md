# Start a Fluvie project

A Fluvie project is a directory holding a composition file, an `assets/` folder,
and a `pubspec.yaml`. It can also live in an existing Flutter app. You maintain
the composition; the CLI manages its preview app and capture host. `fluvie init`
scaffolds the composition setup:

```sh
dart pub global activate fluvie_cli
fluvie init --dir my_reel
cd my_reel
flutter pub get
```

For unpublished Fluvie changes, use the [source-checkout
installer](installation.md#use-an-unpublished-checkout), then run `fluvie init`
in your Flutter project. It discovers that checkout automatically;
`--fluvie-path /path/to/fluvie` selects another one explicitly.

## What you get

Your composition and normal project configuration:

```text
my_reel/
├── pubspec.yaml            # the project: a name, and a dependency on fluvie
├── analysis_options.yaml   # normal Flutter analysis; optional Fluvie lints
├── lib/
│   └── example_video.dart  # your composition
├── assets/                 # your images, clips, audio, fonts
└── .gitignore
```

`init` is not interactive and it never runs `flutter create`. It writes only
new files and merges the required dependency and asset setup into an existing
Flutter project. Your app entry point and other dependencies remain yours.

The flags:

- `--name <name>` names the composition file. It defaults to `example_video`,
  so you get `example_video.dart`.
- `--dir <project>` picks the directory to scaffold into. It defaults to the
  working directory.
- `--force` overwrites files that already exist.
- `--with-ai` adds the optional AI authoring package.
- `--with-lints` adds Fluvie's custom timing and layering lints.
- `--fluvie-path <checkout>` uses a local Fluvie checkout while developing it.

## The composition

A composition file exposes a top-level `Video build()`. That is the only
contract: `fluvie preview` and `fluvie render` call it to get your `Video`. Name
the function something else and pass `--entry <name>`.

Keep it under `lib/`. A preview runs from a generated app that lives outside your
project, and it can only reach your composition through a `package:` URI, which
only a file under `lib/` has. A composition elsewhere still renders, but it
cannot be previewed.

The file opens with two imports. Fluvie's `Animation`, `Clip`, `Image`, and
`Tween` replace Flutter's, so hide those four:

<!-- code-excerpt "examples/gallery/lib/starter/starter_video.dart (imports)" -->
```dart
import 'package:flutter/material.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';
```

Then a `Video` of `Scene`s. The starter is one square scene, a gradient
background, and a title that fades and pops in. You never type a frame number.
[Your first video](your-first-video.md) walks the body line by line.

## Preview it

`fluvie preview` runs your composition live, with hot reload. Edit the file, save,
and the preview redraws:

```sh
fluvie preview ./lib/example_video.dart
```

Preview prints a local browser URL by default. `-d chrome` opens Chrome;
`-d <device>` selects a Flutter desktop device. The CLI provides a local native
media bridge for browser preview, including clip decoding and audio. Browser
sound requires a user gesture. Native encoding tools are managed automatically.

The preview app is generated for you and cached in `~/.cache/fluvie/preview/`,
outside your project. Your project stays a composition file, an `assets/` folder,
and a pubspec.

## Render it

`fluvie render` takes the file directly:

```sh
fluvie render ./lib/example_video.dart
```

The CLI prepares its capture harness and rendering dependencies in an external
user cache, captures every frame with Flutter, then encodes the file. The default
output is `build/fluvie/example_video.mp4`. You do not need FFmpeg
installed: the first render downloads a pinned build and caches it. See
[Managing FFmpeg](../guides/managing-ffmpeg.md).

## Assets

Drop images, clips, audio, and story notes anywhere under `assets/`. Nested
directories are discovered automatically. Original Flutter asset and font
declarations remain available; rendering does not replace your asset block.

This is managed for you because Flutter enumerates a declared asset directory
non-recursively. An `assets/` entry alone bundles only the files sitting directly
in it, and `assets/images/logo.png` goes silently missing at runtime with no build
error. Fluvie discovers each subdirectory that holds files when preparing its render
resources. Declare font families in the normal Flutter `fonts:` section.

## Where to next

- [Create from local assets](authoring-with-assets.md): the fresh Flutter project and AI workflow.

- [Your first video](your-first-video.md): a line-by-line tour of the starter.
- [Core concepts](core-concepts.md): Video, Scene, Time, animate, Defaults.
- [Exporting your video](../guides/exporting-your-video.md): formats, quality,
  and the full `fluvie render` flag list.
- [AI and MCP](../guides/ai-and-mcp.md): have an assistant write real Fluvie code.
