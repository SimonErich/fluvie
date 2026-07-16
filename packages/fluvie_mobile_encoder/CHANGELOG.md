# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the versions follow [Semantic Versioning](https://semver.org/).

## [0.3.1] - 2026-07-16

Lockstep release with the rest of the Fluvie workspace.

## [0.3.0] - 2026-07-16

Lockstep release with the rest of the Fluvie workspace.

## [0.2.0] - 2026-07-06

### Changed

- `OnDeviceVideoRenderer` implements the shared `VideoRenderer<File>`
  contract, re-exported from the barrel, so the same call shape renders on
  every platform.
- Clip audio passes through the shared opt-in audio gate used by all three
  renderers.

## [0.1.10] - 2026-06-24

Lockstep release; no changes to this package since 0.1.9.

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

- On-device `FrameExtractionService` and `VideoProbeService` backed by the
  platform decoder (`MediaMetadataRetriever` / AVFoundation), so on-device
  renders need no ffmpeg. Probed dimensions are capped to the render
  resolution.

## [0.1.4] - 2026-06-22

### Added

- `OnDeviceVideoRenderer.render` takes an `outputFile` to write the MP4 straight
  to a path you choose, and the constructor takes a `networkAllowlist` to gate
  network image hosts.
- A cleanup failure after a render is reported through `onWarning` instead of
  masking the real render error, and the per-render resolver's decoded images are
  disposed once the render is done.

### Changed

- **Breaking:** `render`'s `onProgress` now takes the unified
  `RenderProgressCallback` (a `RenderProgress` with a `RenderPhase`); the
  `OnDeviceProgress`/`OnDeviceRenderPhase` types are removed.

## [0.1.3] - 2026-06-22

### Added

- Render compositions that declare an `Image` or `Clip` on device:
  `OnDeviceVideoRenderer` resolves declared media (inject a `MediaResolver`, or it
  builds and disposes one per render).

### Fixed

- Size the encoder's input buffer for YUV420, not RGBA, so the native encoder no
  longer overruns its input image.
- Resolve the off-screen capture boundary against the app's `BuildOwner`, so
  `GlobalKey.currentContext` finds it.

## [0.1.2] - 2026-06-21

### Added

- On-device audio: materialize and mux audio tracks, including network sources,
  into the encoded MP4 alongside the captured frames.

## [0.1.0] - 2026-06-20

The first public release.

### Added

- `OnDeviceVideoRenderer`: render any Fluvie `Video` (or composition `Widget`) to
  an MP4 entirely on the device, with no FFmpeg, no bundled binary, and no
  network. It drives Fluvie's deterministic capture loop off-screen, then encodes
  the captured frames through the platform's native hardware encoder.
- `MobileVideoEncoder` contract with `MethodChannelMobileVideoEncoder`, backed by
  `MediaCodec` + `MediaMuxer` on Android and `AVAssetWriter` + VideoToolbox on
  iOS. H.264 and HEVC, selectable per render.
- `MobileEncodeRequest`, `MobileVideoCodec`, `defaultBitRate`, and the
  `OnDeviceRenderProgress` phases.
- Opt-in on-device audio: pass `audio: true` to `render` to decode, mix
  (delays, volumes, trims, fades), and mux a `Video`'s declared `Audio` tracks
  with the platform audio encoder. `MobileAudioTrack`, a `MobileAudioMaterializer`
  (with the bundled-asset/file `BundleAudioMaterializer`), and a suppressible
  `onWarning` when a `Video` has audio but `audio` is off. Looping music beds fill
  the video on both Android and iOS.
- `NetworkAudioMaterializer`: opt-in network audio, fetched to a local file behind
  a `NetworkAllowlist`, so a remote bed mixes like a bundled one.
- Riverpod providers (`mobileVideoEncoderProvider`, `onDeviceVideoRendererProvider`)
  and a `FakeMobileVideoEncoder` for tests.

[0.1.0]: https://github.com/SimonErich/fluvie/releases/tag/v0.1.0
