# Installation

Fluvie turns a Flutter widget tree into a real MP4. You write the video as
code, preview it like an app, and render it with the Fluvie CLI and FFmpeg.

In a hurry? `fluvie init` scaffolds a project for you: a composition file, an
`assets/` folder, and a pubspec. See [Start a project](start-a-project.md). To
set it up by hand, read on.

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  fluvie: ^0.3.1
```

Then fetch it:

```sh
flutter pub get
```

## What you need

- Flutter 3.44 or newer with Dart 3.12 or newer.
- Native media tools are automatic. Rendering and local media preview provision
  a pinned FFmpeg/ffprobe pair in a user cache when needed. Warm it with
  `fluvie ffmpeg install`, or select your own pair with `--ffmpeg`/`--ffprobe`.
  See [Managing FFmpeg](../guides/managing-ffmpeg.md).

Check Flutter:

```sh
flutter --version
```

## Use an unpublished checkout

Activate the CLI directly from the repository root without bootstrapping the
whole workspace:

```sh
cd /path/to/fluvie
dart tool/activate_cli.dart
```

The installer prepares a persistent external CLI host using the checkout's
packages, then activates `fluvie`. It keeps authoring setup independent of the
workspace's unrelated app dependencies. Rerun it after dependency changes, or
after CLI source changes when the installer uses its Windows copy fallback.
Linked package source stays live. The default host is under the Fluvie user cache's
`cli/<checkout digest>/fluvie_cli/` directory. `--prepare-only` prints the prepared
host path without global activation; `--install-dir <directory>` chooses its
external parent. `--offline` uses an already resolved package graph without
fetching dependencies.

Point a fresh or existing Flutter project at the same unpublished packages:

```sh
cd /path/to/cat_story
fluvie init
flutter pub get
```

The source-installed CLI discovers its own checkout automatically. Use
`--fluvie-path /path/to/fluvie` to select another checkout explicitly.

For a published release, install the CLI with `dart pub global activate
fluvie_cli` and use normal pub dependencies.

## Develop the whole repository

The repo is a Melos workspace. To work on its apps and package tests, bootstrap it
once:

```sh
melos bootstrap
```

The gallery example app in `examples/gallery/` is the lesson gallery and inspector. Run it
from the repo root so its render button can find the CLI.

## Previewing in a browser

`fluvie preview` runs a composition live, with hot reload:

```sh
fluvie preview ./lib/my_video.dart
```

The default prints a local browser URL with hot reload. Pass `-d chrome` to
open Chrome, or `-d <desktop-device>` for a Flutter desktop app. The CLI provides
its local native media bridge automatically; it can decode formats the browser
alone does not support. Enable sound through the preview control.

Rendering to a file does not need a preview. The headless render pipeline (the
CLI, the API, and the Docker image) produces the final frames correctly on its
own, including loading the real fonts so text never falls back to the boxy test
font.

## Where to next

- [Start a project](start-a-project.md): scaffold a project with `fluvie init`.
- [Your first video](your-first-video.md): build and render lesson 01.
- [Core concepts](core-concepts.md): the ideas behind every Fluvie video.
- [Managing FFmpeg](../guides/managing-ffmpeg.md): how Fluvie finds, downloads, and pins FFmpeg.
