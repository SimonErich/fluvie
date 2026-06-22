# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the versions follow [Semantic Versioning](https://semver.org/).

## [0.1.2] - 2026-06-21

### Added

- On-device audio: audio sources and a resolved audio-track model, mixed through
  the deterministic encode path, including looping audio beds.
- A render-sandbox seam with file and in-memory backends, so a composition can be
  captured to disk or to memory for the on-device mobile and web renderers.

### Changed

- The render service stages audio and frames through the sandbox and runs a
  dedicated frame-capture loop, in place of the previous single render loop.

## [0.1.0] - 2026-06-20

The first public release. The API is feature-complete and well tested; the `0.x`
line means it can still change before `1.0`, so pin a version.

### Added

- The declarative composition model: `Video`, `Scene`, `Scene.sequence`,
  `Scene.centered`, `Background.*`, and the `Defaults` cascade.
- The timing engine: `Time` extensions, `Anchor`, `Trigger`, frame resolution,
  and a deterministic resolved timeline.
- Animation: `.animate([...])`, the preset menu, `Animation.from`/`to`/`keyframes`,
  springs, `Stagger`, and `Repeat`.
- Elements: `Text`, `Typewriter`, `Counter`, `Image`, `Clip`, `Timeline`, `Chart`,
  `Code`, `Terminal`, `Markdown`, `Mermaid`, `WebView`, `Html`, annotations.
- Effects: pixel post-effects, seeded particles, `maskWipe`, parallax, ambient
  motion, and shader animations.
- Transitions, shared-element morphs, and a scene-wide `Camera`.
- Audio and captions: `Audio.music`/`sfx`, beat detection, reactive inputs, SRT
  and VTT captions.
- `resolveAudioMix`: the encoder-neutral `ResolvedAudioMix`/`ResolvedAudioTrack`
  view of a `Video`'s audio (the same timing math the FFmpeg mix uses) for custom
  encoders such as `fluvie_mobile_encoder` and `fluvie_web_encoder`.
- Looping music beds in the FFmpeg path (`-stream_loop`), so a short bed fills the
  whole video on the desktop, server, and web. The `dart:io`-free
  `renderToSandbox` accepts audio through an injected `AudioByteLoader` and
  `stageResolvedAudioToSandbox`, the seam the in-browser encoder mixes through;
  `NetworkAllowlist` is now exported for on-device network audio.
- The power layer: `FluvieTheme`, `Adaptive` and multi-aspect render, templates,
  the `FrameBuilder` escape hatch, and `Export.*` modes.
- Determinism throughout: identical input renders byte-identical frames, with
  content-hash media caching.

[0.1.0]: https://github.com/SimonErich/fluvie/releases/tag/v0.1.0
