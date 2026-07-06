# Changelog

All notable changes to the Fluvie workspace. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[Semantic Versioning](https://semver.org/).

Per-package changelogs live next to each package.

## [0.2.0] - 2026-07-06

The API restructuring release. One authoring barrel, one rendering barrel, one
render contract, and a set of hard renames that make the surface guessable.
Old names are gone, not deprecated; every rename is mechanical. The full map
lives in the [migration guide](documentation/reference/migration.md).

### Changed

- **The barrel split.** `package:fluvie/fluvie.dart` is now the authoring-only
  surface (`Video`, `Scene`, elements, `Animation`, `Trigger`, themes, specs,
  the preview runtime). The render pipeline (`RenderService`, `RenderConfig`,
  `render`, `renderToSandbox`, `renderTemplate`, sandboxes, capture services,
  resolver contracts, `resolveAudioMix`, collectors, `FadeBox`, the wasm
  runtime) moved to the new `package:fluvie/rendering.dart`. The barrel no
  longer re-exports `NumberFormat`; import `package:intl/intl.dart` yourself.
- **One render contract.** `VideoRenderer<T>` unifies the render entry points:
  `DesktopVideoRenderer` (local FFmpeg, returns a `File`),
  `OnDeviceVideoRenderer` (mobile hardware encoder, returns a `File`), and
  `WebVideoRenderer` (ffmpeg.wasm, returns bytes) all implement it.
- **The two-import prelude.** Every example, doc, and template opens with
  `import 'package:flutter/material.dart' hide Animation, Clip, Image, Tween;`
  followed by the fluvie import. The barrel deliberately does not re-export
  Flutter widgets.
- `FfmpegProvider`, `ProcessFfmpegProvider`, `WasmFfmpegProvider`, and
  `ffmpegProviderProvider` are now `FfmpegRunner`, `ProcessFfmpegRunner`,
  `WasmFfmpegRunner`, and `ffmpegRunnerProvider`;
  `RenderService.render(provider:)` is `render(runner:)`.
- `Trigger.after` is now `Trigger.whenEnds`, the parallel twin of
  `Trigger.whenStarts`; the spec kind `"after"` fails with a rename hint.
- **One reveal vocabulary.** Charts (`growIn`/`drawIn`/`sweepIn`/`popIn`),
  `Counter(duration:)`, and annotations (`drawIn`/`slideIn`) all take
  `reveal:`.
- **Complete preset pairs.** `slideFade` is `slideFadeIn`, `maskWipe` is
  `maskWipeIn`; ambient time is `period:` (`spin(per:)` and
  `float(frequency:)` are gone).
- `Timeline` no longer takes an `fps`; it resolves at the enclosing `Video`'s
  fps, so a 60 fps video can no longer silently mistime a schedule.
  `timeline.placements` is `placementsAt(fps)`.
- The decorative photo mat `Frame` is now `PhotoFrame`; "Frame" always means
  the render clock (`FrameBuilder`, `n.frames`, `RawFrame`).

### Added

- New preset mirrors `scaleOut`, `glitchOut`, `slideFadeOut`, and `maskWipeOut`
  complete every directional In/Out pair.
- `fluvie init` wires `fluvie_lints` and `custom_lint` into new projects, so
  the guardrail lints run from the first `dart analyze`.
- The 97% coverage gate now spans all eight packages: `fluvie_validate` and
  `fluvie_ai` joined it (fluvie_ai gained a wire-level MockClient suite over
  the generative provider dispatch).

### Fixed

- Offscreen capture wraps the composition in an ambient `Directionality`, so a
  headless render no longer fails when the tree provides none.
- The in-browser render example works end to end (authenticated web-server
  render, browser render e2e on Google Chrome).
- `// coverage:ignore` reasons are pinned to the collector-safe charset
  (letters, digits, spaces). Punctuation silently dropped a marker and an
  unbalanced pair crashed `flutter test --coverage`; a tool test now enforces
  the syntax.
- Publishing hygiene: `fluvie_validate`'s `custom_lint_builder` pin widened to
  a range, inter-package constraints now track the release version, and every
  package carries `documentation:` and `funding:` metadata plus an `example/`.

### Removed

- The `ai_abstracted` package moved to its own repository at
  <https://github.com/SimonErich/dart_ai_abstracted>. `fluvie_ai` now depends
  on it as a normal pub.dev package (`^0.1.0`) instead of a workspace member.
- Unused repo assets that predated the public release: placeholder
  movie-character images, an orphaned promo render, stale logos, and the
  retired `RELEASE_MIGRATION.md`.

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
  Migrating an existing deployment? See
  [RELEASE_MIGRATION.md at v0.1.9](https://github.com/SimonErich/fluvie/blob/v0.1.9/RELEASE_MIGRATION.md).

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
