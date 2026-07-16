# Start a Fluvie project

A Fluvie project is a directory holding a composition file, an `assets/` folder,
and a `pubspec.yaml`. That is the whole thing. There is no app to run, no
`main.dart`, no capture harness, and no registry to keep in step. `fluvie init`
scaffolds it:

```sh
dart pub global activate fluvie_cli
fluvie init --dir my_reel
cd my_reel
flutter pub get
```

## What you get

Five files, and nothing you have to maintain:

```text
my_reel/
├── pubspec.yaml            # the project: a name, and a dependency on fluvie
├── analysis_options.yaml   # wires custom_lint so fluvie_lints runs as you type
├── lib/
│   └── example_video.dart  # your composition
├── assets/                 # your images, clips, audio, fonts
└── .gitignore
```

`init` is not interactive and it never runs `flutter create`. It writes only
files that are absent, so re-running it in a project is safe and it reports what
it skipped.

The flags:

- `--name <name>` names the composition file. It defaults to `example_video`,
  so you get `example_video.dart`.
- `--dir <project>` picks the directory to scaffold into. It defaults to the
  working directory.
- `--force` overwrites files that already exist.

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

It runs on your desktop by default. That is deliberate: a desktop preview decodes
any clip through FFmpeg, while a browser can only decode what WebCodecs supports.
ProRes is not on that list, so a browser default would show a placeholder for
exactly the compositions you care about. Pass `-d chrome` when you want the
browser anyway, or `-d <device>` for a phone or an emulator.

The preview app is generated for you and cached in `~/.cache/fluvie/preview/`,
outside your project. Your project stays a composition file, an `assets/` folder,
and a pubspec.

## Render it

`fluvie render` takes the file directly:

```sh
fluvie render ./lib/example_video.dart --out example.mp4
```

The CLI generates a capture harness under `my_reel/.fluvie/`, captures every frame
with `flutter test`, then FFmpeg encodes the file. You do not need FFmpeg
installed: the first render downloads a pinned build and caches it. See
[Managing FFmpeg](../guides/managing-ffmpeg.md).

## Assets

Drop images, clips, audio, and fonts anywhere under `assets/`. The CLI re-derives
the pubspec's `assets:` block from the tree on every render and every preview, so
adding `assets/images/logo.png` needs no pubspec edit.

This is managed for you because Flutter enumerates a declared asset directory
non-recursively. An `assets/` entry alone bundles only the files sitting directly
in it, and `assets/images/logo.png` goes silently missing at runtime with no build
error. The CLI writes an entry for every subdirectory that holds files.

## Where to next

- [Your first video](your-first-video.md): a line-by-line tour of the starter.
- [Core concepts](core-concepts.md): Video, Scene, Time, animate, Defaults.
- [Exporting your video](../guides/exporting-your-video.md): formats, quality,
  and the full `fluvie render` flag list.
- [AI and MCP](../guides/ai-and-mcp.md): have an assistant write real Fluvie code.
