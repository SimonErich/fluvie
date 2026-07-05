# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the versions follow [Semantic Versioning](https://semver.org/).

## [0.2.0] - 2026-07-06

The API restructuring release. Old names are gone, not deprecated; every
rename is mechanical. The full map lives in the
[migration guide](https://docs.fluvie.dev/reference/migration/).

### Changed

- **Barrel split.** `package:fluvie/fluvie.dart` keeps only the authoring
  surface; the pipeline moved to the new `package:fluvie/rendering.dart`
  (`RenderService`, `RenderConfig`, `render`, `renderToSandbox`,
  `renderTemplate`, sandboxes, capture services, resolver contracts,
  `resolveAudioMix`, collectors, `FadeBox`, the wasm runtime,
  `FfmpegVersion`). `NumberFormat` is no longer re-exported; import
  `package:intl/intl.dart` yourself.
- `FfmpegProvider`, `ProcessFfmpegProvider`, `WasmFfmpegProvider`, and
  `ffmpegProviderProvider` are now `FfmpegRunner`, `ProcessFfmpegRunner`,
  `WasmFfmpegRunner`, and `ffmpegRunnerProvider`;
  `RenderService.render(provider:)` is `render(runner:)`.
- `Trigger.after` is now `Trigger.whenEnds`, the parallel twin of
  `Trigger.whenStarts`; the spec kind `"after"` fails with a rename hint.
- **One reveal vocabulary.** Charts (`growIn`/`drawIn`/`sweepIn`/`popIn`),
  `Counter(duration:)`, and annotations (`drawIn`/`slideIn`) all take
  `reveal:`.
- `Animation.slideFade` is `slideFadeIn`; `Animation.maskWipe` is
  `maskWipeIn`; ambient presets take `period:` (`spin(per:)` and
  `float(frequency:)` are gone).
- `Timeline` no longer takes an `fps`; it resolves at the enclosing
  `Video`'s fps, so a 60 fps video can no longer silently mistime a
  schedule. `timeline.placements` is `placementsAt(fps)`.
- The decorative photo mat `Frame` is now `PhotoFrame`; "Frame" always
  means the render clock (`FrameBuilder`, `n.frames`, `RawFrame`).

### Added

- The `VideoRenderer<T>` render contract and `DesktopVideoRenderer`;
  `OnDeviceVideoRenderer` and `WebVideoRenderer` implement the same shape.
- Preset mirrors `scaleOut`, `glitchOut`, `slideFadeOut`, and `maskWipeOut`
  complete every directional In/Out pair.

### Fixed

- Offscreen capture wraps the composition in an ambient `Directionality`,
  so a headless render no longer fails when the tree provides none.

## [0.1.10] - 2026-06-24

### Added

- Generative-media prerender seam. Declare AI-generated visual and audio sources
  with `GenerativeMedia` / `GenerativeAudio` (`GenerativeSource`,
  `GenerativeKind`, `GenerativeCarrier`) and resolve them before the frame loop
  through the new `GenerativeResolver` contract (`generativeResolverProvider`,
  defaulting to `NoGenerativeResolver`). `collectGenerativeSources` plus the now
  generative-aware media, clip, clip-audio, and audio collectors fold each
  produced file back in as a plain `MediaSource.file` / `AudioSource.file`, so a
  generated video (with Veo 3 audio) and generated music mix and stay in sync like
  local assets. The render orchestrators run generation before media
  pre-resolution; the real backend lives in `fluvie_ai`.
- The default FFmpeg render now mixes a clip's embedded audio. `render()` probes
  every clip and the encoder stages the audio of any clip that carries a track
  (regular `Clip` or a generated video such as Veo 3), delayed to its scene
  window. `ClipMetadata` gained `hasAudio` (the probe reports it) so a silent
  clip is never given a broken audio map.
- `render()` and `renderToSandbox()` accept `onGenerativeProgress` to surface
  per-asset generation progress (`GenerativeProgress`) before the frame loop.

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

- Non-fatal spec diagnostics: an unknown spec property is surfaced on the
  default render path instead of being silently dropped, backed by the
  JSON-schema variants and defs.
- A pluggable `ClipFramePreparer` contract so a host can pre-resolve clip
  frames without ffmpeg.

## [0.1.4] - 2026-06-22

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
