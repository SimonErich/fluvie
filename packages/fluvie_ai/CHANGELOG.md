# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the versions follow [Semantic Versioning](https://semver.org/).

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
