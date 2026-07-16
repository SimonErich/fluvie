# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the versions follow [Semantic Versioning](https://semver.org/).

## [0.3.0] - 2026-07-15

The single-file release. Point the CLI at a `.dart` file and it generates the
harness and the preview app for you, so a project is a composition, an `assets/`
folder, and a pubspec. See the
[migration guide](https://docs.fluvie.dev/reference/migration/).

### Added

- **`fluvie preview <file.dart>`**: a live, hot-reloading preview. Edit the
  composition, save, watch it redraw. `-d <device>` picks the device; the default
  is the host desktop, not the browser, because a desktop preview decodes any clip
  through FFmpeg while a browser is limited to what WebCodecs supports (no
  ProRes). The app is generated and cached in `~/.cache/fluvie/preview/<hash>/`,
  outside the project.
- **`fluvie render <file.dart> --out <file>`**: render a composition file
  directly. The capture harness is generated under `<project>/.fluvie/` per
  render, so there is nothing to commit and nothing to drift.
- `--entry <name>` on `render` and `preview`: the top-level function returning the
  `Video`. Defaults to `build`.
- `--cache` on `render`: reuse cached frames for a `.dart` target. Off by default,
  because the render digest keys on the config and the composition key, never on
  the composition itself, so an edited file with the same size and frame count
  would replay stale frames.

### Changed

- **BREAKING. `fluvie init` scaffolds a project, not an app.** It writes exactly
  `pubspec.yaml`, `.gitignore`, `<name>.dart`, `assets/.gitkeep`, and
  `analysis_options.yaml`. It no longer runs `flutter create`, no longer
  scaffolds a capture harness or a registry, and is no longer interactive.
- **BREAKING. `fluvie init` flags are now `--name`, `--dir`, and `--force`.**
  `--path`, `--render` / `--no-render`, and `--yes` / `-y` are gone. With no
  prompts there is nothing to say yes to, and with no harness there is nothing to
  skip.
- A scaffolded composition exposes a top-level `Video build()` rather than a
  named builder registered under a key.
- The `flutter: assets:` pubspec block is CLI-managed and re-derived on every
  render and preview. Flutter enumerates a declared asset directory
  non-recursively, so an `assets/` entry alone silently misses
  `assets/images/foo.png`; the CLI writes an entry for every subdirectory that
  holds files.
- The generated harness drives fluvie's `renderVideo`, so the CLI and any other
  host run the same capture path.

### Fixed

- The Playground no longer requires `examples/gallery` to exist on the render
  host: a code render stages its harness against any Fluvie project.

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
