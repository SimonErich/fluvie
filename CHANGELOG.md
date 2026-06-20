# Changelog

All notable changes to the Fluvie workspace. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[Semantic Versioning](https://semver.org/).

Per-package changelogs live next to each package.

## [0.1.0] - 2026-06-20

The first public release of the whole workspace. See each package's CHANGELOG for
its detail. The API works and is well tested; the `0.x` line means it can still
move before `1.0`, so pin a version.

### Added

- `fluvie` 0.1.0: the full declarative video library (composition, timing,
  animation, elements, effects, transitions, audio, captions, theme, templates,
  multi-aspect export), deterministic and content-hash cached.
- `fluvie_lints` 0.1.0: the ten-rule custom_lint set (layering, determinism,
  timing, and migration rules) with quick-fixes.
- `fluvie_cli` 0.1.0: the headless renderer (capture with `flutter test`, encode
  with FFmpeg) and the `mp4`/`gif`/`imageSequence`/`transparent` export formats.
- `fluvie_ai` 0.1.0: author a video from a prompt; a language model writes a
  deterministic `VideoSpec` that renders byte-identically.
- `fluvie_api` 0.1.0: the HTTP render API (local or S3 storage) and its web-safe
  client.
- `fluvie_mcp` 0.1.0: an MCP server that lets an AI assistant author and render
  Fluvie videos, over stdio or HTTP.
- The example app: twelve runnable lessons and a scrubbable MVVM inspector.
- The documentation tree, with compiled and tested snippets throughout.

### Known limitations

- The live headless-Chrome snapshot transport (Mermaid, WebView, Html) is
  deferred behind an injected `SnapshotService`; those elements ship
  `@experimental`.

[0.1.0]: https://github.com/SimonErich/fluvie/releases/tag/v0.1.0
