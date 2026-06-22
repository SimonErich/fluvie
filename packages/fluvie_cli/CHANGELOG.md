# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the versions follow [Semantic Versioning](https://semver.org/).

## [0.1.3] - 2026-06-22

Lockstep release with the rest of the workspace; no changes to this package.

## [0.1.2] - 2026-06-21

### Added

- A pinned FFmpeg provisioner: download, cache, and use a known-good FFmpeg build,
  so a render works without a system FFmpeg on `PATH`.
- Impeller capture support in the render pipeline.

## [0.1.0] - 2026-06-20

The first public release.

### Added

- The `render` command: capture a composition with `flutter test`, then encode
  it with FFmpeg into a real video file.
- Export formats: `mp4`, `gif`, `imageSequence`, and `transparent` (WebM).
- Options for quality, aspect ratio, poster frame, draft frame counts, cache
  bypass, sandbox retention, and verbose output.
- A typed exit-code contract (`0` ok, `64` usage, `1` operational failure).
- Safe FFmpeg invocation: argument lists, never shell strings, with bitexact
  flags on a single thread, so re-rendering reproduces the same file per machine.

[0.1.0]: https://github.com/SimonErich/fluvie/releases/tag/v0.1.0
