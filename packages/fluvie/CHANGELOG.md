# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.3.1] - 2026-07-16

### Changed

- Extracted clip frames are cached across runs, so re-rendering a
  composition that embeds a `Clip` reuses the frames instead of decoding
  them again.

### Fixed

- The temporary clip-frame store is swept and deleted synchronously, so a
  render no longer leaks temp frame directories.

## [0.3.0] - 2026-07-15

The single-file release. A composition is a file with a top-level
`Video build()`, and `renderVideo` is the one capture entry a host drives.
See the [migration guide](https://docs.fluvie.dev/reference/migration/).

### Added

- **`renderVideo`** on `package:fluvie/rendering.dart`: the one capture entry a
  host drives. It takes a `Video` and derives geometry, media, audio, captions,
  and reactive audio from it; the host supplies only `pumpWidget`, `pumpFrame`,
  `setViewSize`, and `runAsync`. Encoding stays out of it: the returned
  `RenderManifest` carries the complete ffmpeg argument array.
- `SetViewSize`, `ShellRunAsync`, and `runAsyncDirectly` on the rendering
  barrel: the host seams `renderVideo` takes.
- `parseAspect`, `parseQuality`, `parseExportFormat`, `parsePosterTime`, and
  `writeRenderProgress` are now public on `package:fluvie/rendering.dart`, so a
  generated harness turns CLI defines into typed arguments without reaching into
  `src/`.
- `LivePlayer` and `LivePlaybackController`: clock-driven live playback of
  a composition (play, pause, seek, hold, playRange, rate) on the same
  frame pipeline capture uses.
- `introspectTimeline`: the resolved timeline as data, with per-element
  windows and lookups by anchor, key, or widget.
- `LocalMotionScope`: mount animated content under a `Video` after the
  composition resolved, on its own frame base.

### Fixed

- **WebM/VP9 clips work, including alpha.** A `.webm` failed the probe because
  Matroska stores no `nb_frames` and no per-stream duration; the frame count is
  now counted with a `-count_frames` pass, falling back to duration times frame
  rate. The pass runs only for a container that stored no count, so an MP4 never
  pays it.
- **VP9 alpha is no longer silently dropped.** VP9 codes alpha as a second layer
  that only `libvpx-vp9` reads; ffmpeg's native `vp9` decoder ignored it and the
  clip composited over black. A VP9 stream tagged `ALPHA_MODE=1` now selects
  `libvpx-vp9`. An opaque VP9 clip stays on the native decoder, which is much
  faster.
- `LivePlaybackController` survives a ticker restart: when a remounted
  `LivePlayer` hands it a fresh ticker (elapsed starts over at zero), the
  clock rebases at the current frame and carries on instead of rewinding
  to frame 0 and replaying.

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
- `FfmpegProvider` and `ffmpegProviderProvider` are now `FfmpegRunner` and
  `ffmpegRunnerProvider`, which selects the platform runner through
  `FfmpegRunnerRegistry`; `RenderService.render(provider:)` is `render(runner:)`.
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
