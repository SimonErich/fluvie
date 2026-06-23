# Installation

Fluvie turns a Flutter widget tree into a real MP4. You write the video as
code, preview it like an app, and render it with the Fluvie CLI and FFmpeg.

In a hurry? `fluvie init` scaffolds a runnable starter for you, in a new project
or alongside an existing one. See [Start a project](start-a-project.md). To set
it up by hand, read on.

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  fluvie: ^0.1.0
```

Then fetch it:

```sh
flutter pub get
```

## What you need

- Flutter 3.44 or newer.
- FFmpeg, for rendering (previews do not need it). You do not have to install
  it: the first render downloads a pinned FFmpeg build and caches it. Run
  `fluvie ffmpeg install` to fetch it ahead of time, or point `--ffmpeg` /
  `FLUVIE_FFMPEG` at your own. See [Managing FFmpeg](../guides/managing-ffmpeg.md).

Check Flutter:

```sh
flutter --version
```

## Working inside this repository

The repo is a Melos workspace. Bootstrap it once:

```sh
melos bootstrap
```

The example app in `example/` is the lesson gallery and inspector. Run it
from the repo root so its render button can find the CLI.

## Previewing on the desktop

You preview a video by running it like a normal Flutter app. Use Impeller,
Flutter's current renderer, so shaders, grain, and blends look the way the
rendered video does:

```sh
flutter run --enable-impeller
```

Rendering to a file does not need this. The headless render pipeline (the CLI,
the API, and the Docker image) produces the final frames correctly on its own,
including loading the real fonts so text never falls back to the boxy test font.

## Where to next

- [Start a project](start-a-project.md): scaffold a runnable starter with `fluvie init`.
- [Your first video](your-first-video.md): build and render lesson 01.
- [Core concepts](core-concepts.md): the ideas behind every Fluvie video.
- [Managing FFmpeg](../guides/managing-ffmpeg.md): how Fluvie finds, downloads, and pins FFmpeg.
