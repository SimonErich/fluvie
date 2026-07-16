# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the versions follow [Semantic Versioning](https://semver.org/).

## [0.3.1] - 2026-07-16

Lockstep release with the rest of the Fluvie workspace.

## [0.3.0] - 2026-07-16

Lockstep release with the rest of the Fluvie workspace.

## [0.2.0] - 2026-07-06

### Changed

- The authored spec vocabulary tracks the 0.2.0 surface (`whenEnds`,
  `reveal`, `period`, `slideFadeIn`).
- The AI client contract is one public type per file; imports stay on
  `package:fluvie_ai/fluvie_ai.dart`.
- The generative provider dispatch is covered by a wire-level MockClient
  suite; the package joined the workspace 97% coverage gate at 100%.

## [0.1.10] - 2026-06-24

### Added

- Generative media. Provider widget sugar (`GenerativeImage.flux`/`.gemini`/
  `.openai`, `GenerativeVideo.veo`, `GenerativeMusic.suno`,
  `GenerativeSpeech.eleven`, `GenerativeSoundFx.eleven`) plus the
  `GenerativeMediaResolver` that produces and caches assets under
  `.fluvie/generative/` (keyed by prompt, seed, and options, with offline and
  budget guards), built on the new `ai_abstracted` package. Install it with
  `fluvieGenerativeResolverFor()` from the `dart:io` native entrypoint
  `package:fluvie_ai/generative.dart`.

### Changed

- Authoring now runs on `ai_abstracted` (no duplicated provider HTTP).

## [0.1.9] - 2026-06-23

Lockstep maintenance release; demo (mobile layout) and CI fixes only, no library changes since 0.1.8.

## [0.1.8] - 2026-06-23

Lockstep maintenance release; demo and deploy fixes only, no library changes since 0.1.6.

## [0.1.7] - 2026-06-23

Lockstep maintenance release; demo and deploy fixes only, no library changes since 0.1.6.

## [0.1.6] - 2026-06-23

Lockstep maintenance release; no functional changes since 0.1.5.

## [0.1.5] - 2026-06-23

### Changed

- The author validates a decoded spec against the schema and feeds an
  off-schema spec back into the repair loop, and the prompt now carries a
  complete worked example.

## [0.1.4] - 2026-06-22

Lockstep release with the rest of the workspace; a documentation touch-up only.

## [0.1.3] - 2026-06-22

Lockstep release with the rest of the workspace; no changes to this package.

## [0.1.2] - 2026-06-21

Lockstep release with the rest of the workspace; no changes to this package.

## [0.1.0] - 2026-06-20

The first public release.

### Added

- `LlmVideoAuthorService`: turn a prompt into a deterministic `VideoSpec`, with a
  validate-then-repair loop (up to three rounds) against Fluvie's JSON Schema.
- A provider-agnostic `AiClient` with built-in clients for Claude, Gemini,
  Mistral, and local Ollama, selectable from the environment with
  `aiClientFromEnv`.
- Spec refinement: pass an existing spec as `base` and a rendered frame as
  `lastFrame` so multimodal providers can see what they are editing.
- `FakeAiClient` for tests, plus Riverpod providers for wiring.

[0.1.0]: https://github.com/SimonErich/fluvie/releases/tag/v0.1.0
