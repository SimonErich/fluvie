# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the versions follow [Semantic Versioning](https://semver.org/).

## [0.2.0] - 2026-07-06

### Changed

- Packaging only: the package gained its LICENSE, a runnable example, and a
  publish-workflow job, and now publishes to pub.dev in lockstep with the
  rest of the workspace.

## [0.1.10] - 2026-06-24

### Added

- Initial release. Provider-agnostic contracts for text, image, video, speech,
  sound-effect, and music generation behind one typed request/result API, with a
  shared HTTP transport (retry + backoff + async-job polling), an environment
  credential loader, a provider registry, and in-memory fakes for every
  capability. Ships clients for Google Gemini and Veo, OpenAI, Black Forest Labs
  Flux, ElevenLabs, and Suno (via sunoapi.org).
- Multi-turn text conversations (`TextRequest.history` plus an optional
  `TextRequest.image`) and text clients for Anthropic Claude, Mistral, and Ollama.
