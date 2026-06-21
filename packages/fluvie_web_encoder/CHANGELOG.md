# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the versions follow [Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-06-21

The first public release.

### Added

- `WebVideoRenderer`: render any Fluvie `Video` to an MP4 entirely in the
  browser. It drives Fluvie's deterministic capture loop off-screen into an
  in-memory sandbox, then encodes the frames with ffmpeg.wasm — which runs the
  exact same argument plan as the desktop and server paths, so H.264, GIF, and
  transparent WebM all work with no reimplementation.
- `WebVideoEncoder` over Fluvie's `WasmRuntime`, `OffscreenWebCaptureHost`, and
  the `WebCaptureHost` seam.
- Opt-in by design: only apps that depend on this package load the ffmpeg.wasm
  bridge, so API-only and mobile-only apps stay light.

[0.1.0]: https://github.com/SimonErich/fluvie/releases/tag/v0.1.0
