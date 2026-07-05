# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the versions follow [Semantic Versioning](https://semver.org/).

## [0.2.0] - 2026-07-06

### Changed

- `fluvie init` wires `fluvie_lints` and `custom_lint` into the scaffolded
  project, so the guardrail lints run from the first `dart analyze`.
- The bundled templates and generated harnesses use the 0.2.0 surface (the
  two-import prelude, `package:fluvie/rendering.dart` for the pipeline, and
  the renamed presets and triggers).

## [0.1.10] - 2026-06-24

### Changed

- Capture-harness auto-discovery also probes an `examples/gallery` subproject, so
  `fluvie render` and `fluvie list` resolve the relocated monorepo gallery from
  the repo root.

## [0.1.9] - 2026-06-23

Lockstep maintenance release; demo (mobile layout) and CI fixes only, no library changes since 0.1.8.

## [0.1.8] - 2026-06-23

Lockstep maintenance release; demo and deploy fixes only, no library changes since 0.1.6.

## [0.1.7] - 2026-06-23

Lockstep maintenance release; demo and deploy fixes only, no library changes since 0.1.6.

## [0.1.6] - 2026-06-23

Lockstep maintenance release; no functional changes since 0.1.5.

## [0.1.5] - 2026-06-23

### Added

- `fluvie init` scaffolds a new Fluvie project or adds Fluvie to an existing
  Flutter app from an embedded starter template, prompting only for what it
  cannot infer.

## [0.1.4] - 2026-06-22

Lockstep release. Documentation only: the README describes reproducible renders
on the same machine rather than guaranteeing byte-identical output.

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
