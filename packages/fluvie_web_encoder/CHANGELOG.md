# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the versions follow [Semantic Versioning](https://semver.org/).

## [0.1.2] - 2026-06-21

### Added

- On-device audio: mix audio into the in-browser MP4 through the same ffmpeg.wasm
  argument plan that encodes the captured frames.

## [0.1.0] - 2026-06-21

The first public release.

### Added

- `WebVideoRenderer`: render any Fluvie `Video` to an MP4 entirely in the
  browser. It drives Fluvie's deterministic capture loop off-screen into an
  in-memory sandbox, then encodes the frames with ffmpeg.wasm — which runs the
  exact same argument plan as the desktop and server paths, so H.264, GIF, and
  transparent WebM all work with no reimplementation.
- `FluvieWebStage`: wrap your app once to give in-browser capture an off-screen
  surface inside the app's own pipeline; `WebVideoRenderer` captures through it
  by default.
- `WebVideoEncoder` over Fluvie's `WasmRuntime`, plus the `WebCaptureHost` seam.
- Opt-in in-browser audio: pass `audio: true` to mix and mux a `Video`'s `Audio`
  tracks with the same `amix` plan the desktop uses (looping beds, fades, trims,
  multi-track). `WebAudioMaterializer`/`BundleWebAudioMaterializer` load asset
  audio through `rootBundle` and allowlisted network audio; a suppressible
  `onWarning` fires when a `Video` has audio but `audio` is off.
- Opt-in by design: only apps that depend on this package load the ffmpeg.wasm
  bridge, so API-only and mobile-only apps stay light.

[0.1.0]: https://github.com/SimonErich/fluvie/releases/tag/v0.1.0
