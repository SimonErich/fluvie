# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the versions follow [Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-06-20

The first public release.

### Added

- The `render` command: capture a composition with `flutter test`, then encode
  it with FFmpeg into a real video file.
- Export formats: `mp4`, `gif`, `imageSequence`, and `transparent` (WebM).
- Options for quality, aspect ratio, poster frame, draft frame counts, cache
  bypass, sandbox retention, and verbose output.
- A typed exit-code contract (`0` ok, `64` usage, `1` operational failure).
- Deterministic renders: FFmpeg is invoked with argument lists and bitexact
  flags, so re-rendering reproduces the same output per machine.

[0.1.0]: https://github.com/SimonErich/fluvie/releases/tag/v0.1.0
