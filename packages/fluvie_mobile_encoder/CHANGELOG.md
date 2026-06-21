# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the versions follow [Semantic Versioning](https://semver.org/).

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
  `onWarning` when a `Video` has audio but `audio` is off.
- Riverpod providers (`mobileVideoEncoderProvider`, `onDeviceVideoRendererProvider`)
  and a `FakeMobileVideoEncoder` for tests.

[0.1.0]: https://github.com/SimonErich/fluvie/releases/tag/v0.1.0
