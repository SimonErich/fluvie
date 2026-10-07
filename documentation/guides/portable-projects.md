# Portable video projects

Bundle a readable Dart entry, assets, fonts, dependency resolution and settings:

```sh
fluvie bundle create lib/my_video.dart --out my_video.fluvie.zip
fluvie bundle inspect my_video.fluvie.zip --json
fluvie bundle replay my_video.fluvie.zip --dir replayed_video
```

Creation preserves the working project's source, pubspec and lock. Replay
restores a new project, resolves its pinned dependencies and renders through the
managed harness. No original project directory is required.

## What travels with the video

- Project-local Dart, the `assets/` directory and declared Flutter assets,
  shaders and font files.
- A copied pubspec and lock. Local and Git dependencies are vendored; their
  copied manifests and lock descriptions use relative paths.
- Render settings supplied with `--aspect`, `--quality` and `--format`.
- A source revision, SDK descriptor and SHA-256/byte-length record for every file.
- Explicit evidence supplied through repeated `--include` options.

Hosted dependencies keep their locked versions and checksums. Replay uses
`flutter pub get --enforce-lockfile`; an incompatible resolution fails instead
of upgrading packages silently. Use the recorded Flutter SDK for reproduction.
Hosted packages need their normal pub cache or network access. Flutter and
FFmpeg binaries are not embedded. FFmpeg follows the normal managed provisioning
path, or use `--ffmpeg`, `--ffprobe` and `--no-download` with a prepared pair.

```sh
fluvie bundle create lib/my_video.dart --out my_video.fluvie.zip \
  --include build/fluvie/my_video.mp4 \
  --include build/fluvie/my_video.review
```

The ZIP has `project/`, `vendor/`, optional `evidence/`, and `bundle.json`.
Original manifests are retained under `provenance/`. Generated caches, build
trees and hidden files such as `.env` are excluded. Explicit evidence is copied
only when selected.

## Inspect or restore without rendering

```sh
fluvie bundle inspect my_video.fluvie.zip --json
fluvie bundle unpack my_video.fluvie.zip --dir restored_video
```

Inspection verifies the archive without running Dart. Extraction rejects unsafe
paths, symbolic links, duplicate names, unrecorded files, size mismatches and
content-hash mismatches. It bounds decompression to 2 GiB and 20,000 files.
Only a completely verified project is published at the new destination.
An existing destination is never merged or overwritten.

`VideoProjectBundle` exposes the same create, inspect and unpack behavior for
CLI hosts, with configurable byte/file budgets.

## Reproduction scope

The bundle includes declared local inputs. Arbitrary runtime file reads,
network content and generated resources are not discoverable from a Dart entry
alone. Materialize those inputs into the project before bundling. File-based
source strings should use project-relative paths; asset sources should use
their exact asset keys.

Hash verification establishes file integrity against the included manifest.
It does not establish who authored a bundle or make its Dart safe to execute.
Inspect an unfamiliar project before explicitly replaying it. Pixel identity
across different Flutter engines, fonts or platforms remains a separate check.

## Where to next

- [Authoring workspace](authoring-workspace.md): inspect and compare frames.
- [Reviewing a video](reviewing-a-video.md): retain review evidence.
- [Exporting your video](exporting-your-video.md): settings and toolchain receipts.
