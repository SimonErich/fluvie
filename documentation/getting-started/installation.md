# Installation

Fluvie turns a Flutter widget tree into a real MP4. You write the video as
code, preview it like an app, and render it with the Fluvie CLI and FFmpeg.

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  fluvie: ^1.0.0
```

Then fetch it:

```sh
flutter pub get
```

## What you need

- Flutter 3.44 or newer.
- FFmpeg on your PATH. Rendering needs it; previews do not.

Check both:

```sh
flutter --version
ffmpeg -version
```

## Working inside this repository

The repo is a Melos workspace. Bootstrap it once:

```sh
melos bootstrap
```

The example app in `example/` is the lesson gallery and inspector. Run it
from the repo root so its render button can find the CLI.

## Where to next

- [Your first video](your-first-video.md): build and render lesson 01.
- [Core concepts](core-concepts.md): the ideas behind every Fluvie video.
