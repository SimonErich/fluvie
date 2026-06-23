# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the versions follow [Semantic Versioning](https://semver.org/).

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

- Frames are encoded to one PNG each through the engine codec, keeping peak
  memory bounded to a single frame instead of buffering every raw frame.

## [0.1.4] - 2026-06-22

### Added

- `WebVideoRenderer` resolves and paints declared image media (asset, network,
  memory) in the browser. It builds a web image resolver per render from
  `mediaResolverProvider`, or accepts an injected `mediaResolver`.
- In-browser video `Clip` decoding through WebCodecs. `createWebClipDecoder`
  bridges to a page-global `FluvieClipDecoder` (a WebCodecs `VideoDecoder` plus
  demuxer, the same way ffmpeg.wasm lives behind `FluvieFfmpeg`);
  `WebVideoRenderer` wires it into the per-render resolver by default. Without the
  bridge a clip fails with a clear typed error.
- `downloadBytes` saves rendered bytes from the page as a browser download, and
  the `WebVideoRenderer` constructor takes a `networkAllowlist` to gate network
  image hosts.
- A cleanup failure after a render is reported through `onWarning` instead of
  masking the real render error.

### Changed

- **Breaking:** `render`'s `onProgress` now takes the unified
  `RenderProgressCallback` (a `RenderProgress` with a `RenderPhase`): per-frame
  capture progress, then the encoding and complete phases.

## [0.1.3] - 2026-06-22

Lockstep release with the rest of the workspace; no changes to this package.

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
