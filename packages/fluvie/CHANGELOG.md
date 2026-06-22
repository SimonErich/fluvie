# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- In-browser rendering paints declared image media. A `dart:io`-free
  `WebImageMediaResolver` (selected by `mediaResolverProvider` on web) resolves
  and decodes asset, network, and memory `Image` sources before the frame loop,
  and `renderToSandbox` accepts an injected resolver. Audio, snapshots, and
  captions are not supported on web yet and fail with a clear typed error.
- On-device video `Clip` support, shared across desktop and web. A
  `ClipResolveCache` mixin probes a clip, plans the source frames its scene
  window reads (`planClipFrames`), extracts and caches them, and serves them
  synchronously per frame; a clip pre-pass (`preResolveCompositionClips`) runs
  before the frame loop in every render entry point. The browser decodes through
  an injected `WebClipDecoder` (WebCodecs), wired by `webClipDecoderProvider`;
  with no decoder a clip fails with a clear typed error.
- Shared on-device render primitives so the mobile and web encoders stay thin and
  consistent: `RenderPhase` + `RenderProgress`/`RenderProgressCallback`,
  `frameCountFor`, `runGuarded` (cleanup that never masks the render error),
  `runStage` (stamps a stage onto a thrown `FluvieRenderException`),
  `DisposableResolver`, and `resolverScope`.
- `FluvieRenderException.stage` records whether a failure happened while capturing
  or encoding.
- Media resolvers (`MediaRepository`, `WebImageMediaResolver`) now `dispose()`
  their decoded images, freeing native memory instead of waiting for GC.

## [0.1.3] - 2026-06-22

### Added

- Off-screen renders can pre-resolve a composition's declared media: an injected
  `MediaResolver` decodes and caches the `Image`/`Clip` sources before the first
  frame, so the on-device mobile and web renderers can paint declared media.

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
- Content-hash media caching, so an unchanged frame is read from cache rather
  than redrawn.

[0.1.0]: https://github.com/SimonErich/fluvie/releases/tag/v0.1.0
