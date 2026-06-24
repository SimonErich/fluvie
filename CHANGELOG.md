# Changelog

All notable changes to the Fluvie workspace. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[Semantic Versioning](https://semver.org/).

Per-package changelogs live next to each package.

## [0.1.10] - 2026-06-24

### Added

- AI generative media: declare AI-generated image, video, and audio sources with
  `GenerativeMedia` / `GenerativeAudio` and resolve them before the frame loop
  through the new `GenerativeResolver` seam (default `NoGenerativeResolver`), so
  generated clips and music fold back in as plain media and stay in sync. A new
  provider-agnostic `ai_abstracted` package (Gemini/Veo, OpenAI, Flux, ElevenLabs,
  Suno, with fakes) powers it, bound in `fluvie_ai`.
- A set of focused, kitten-themed example apps under `examples/`, one per
  rendering path, sharing a new `examples/kitten_kit` package (theme, sample
  media, and reusable composition builders):
  - `cli_quickstart`: render a composition from the terminal with the CLI.
  - `desktop_studio`: a Linux desktop studio that renders to a file via the CLI.
  - `mobile_purrfect`: an Android app that renders on-device with the native encoder.
  - `web_browser_studio`: a meme maker that renders fully in the browser (ffmpeg.wasm).
  - `web_server_studio`: a promo studio that renders on a Fluvie render server.
- End-to-end coverage for the example apps in CI: per-app build jobs, a real CLI
  render with an ffprobe assertion, and advisory GUI/wasm/emulator render jobs.
  The web apps are also served from a new `fluvie-examples` Docker image, and the
  builds upload as workflow artifacts.
- An [example apps guide](documentation/guides/example-apps.md).

### Changed

- Moved the lesson gallery from `example/` to `examples/gallery/` (the package
  name stays `fluvie_example`) and updated every reference: the melos workspace
  and scripts, CI workflows, Docker images, the website build, the documentation
  code-excerpts, and the tool scripts.
- `fluvie_cli` project discovery also probes an `examples/gallery` subproject, so
  the relocated gallery resolves from the repo root.

## [0.1.4] - 2026-06-22

### Changed

- Consolidated `fluvie_api` and `fluvie_mcp` into a single `fluvie_server`
  package and image: the render API, the MCP server, and a new documentation
  helper now run from one self-hostable binary, each toggled by an environment
  variable (`FLUVIE_ENABLE_API` / `_MCP` / `_DOCS`). The `/v1` routes, the `/mcp`
  contract, and every env var name are unchanged, so existing clients keep
  working; the web-safe client moved to `package:fluvie_server/client.dart`.
  Migrating an existing deployment? See [RELEASE_MIGRATION.md](RELEASE_MIGRATION.md).

### Added

- A documentation helper: the MCP server can search and read the bundled Fluvie
  docs (`list_docs`, `search_docs`, `get_doc`) so a coding assistant can learn
  Fluvie offline. Two MCP modes — `docs` (helper only) and `build` (helper plus
  render/author tools). MCP build mode renders in-process via a `LocalRenderGateway`
  when the API is enabled, or against a remote `FLUVIE_API_URL` otherwise.
- Two images: `fluvie-server` (full, with the render toolchain) and a slim
  `fluvie-server-docs` (docs/MCP only, no Flutter or ffmpeg).

### Removed

- The `fluvie_api` and `fluvie_mcp` packages and their images (`fluvie-api`,
  `fluvie-mcp`). Depend on `fluvie_server` and use the `fluvie-server` /
  `fluvie-server-docs` images instead.

## [0.1.3] - 2026-06-22

On-device rendering of compositions that declare media, plus release-tooling
fixes so every package publishes from the umbrella tag.

### Added

- On-device media: off-screen renders pre-resolve declared `Image`/`Clip`
  sources, and the mobile renderer paints them on device.

### Fixed

- The mobile encoder's input buffer size (YUV420, not RGBA) and the off-screen
  capture boundary lookup.
- The lockstep publish: every package CHANGELOG is stamped with the release
  version, so pub.dev's dry-run no longer rejects the tag. `tool/set_version.sh`
  now stamps the CHANGELOGs as part of the bump.

### Changed

- The marketing site builds from the Astro project in `web/site`; the old
  data-driven landing is removed.

[0.1.3]: https://github.com/SimonErich/fluvie/releases/tag/v0.1.3

## [0.1.2] - 2026-06-21

Added more deployment options, local mobile and local web renderer.

### Added

- added local mobile renderer
- added local web renderer
- improved deployment strategy

[0.1.2]: https://github.com/SimonErich/fluvie/releases/tag/v0.1.2

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
