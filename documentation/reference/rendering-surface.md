# The rendering surface

Fluvie ships two barrels. `package:fluvie/fluvie.dart` is the authoring
surface: everything you type inside a `Video`. `package:fluvie/rendering.dart`
is the pipeline surface: everything that produces frames from one. You import
it in a render harness, an encoder backend, or a server. You never import it
in a composition.

<!-- code-excerpt-ignore: illustrates the import split, not runnable Fluvie API -->
```dart
import 'package:fluvie/fluvie.dart';    // author: Video, Scene, Animation, ...
import 'package:fluvie/rendering.dart'; // host: capture, sandboxes, encoders
```

The two barrels are disjoint. Autocomplete on the authoring import stays
declarative; the pipeline machinery lives here.

## What lives here

| Group | Surface |
| --- | --- |
| Renderers | `VideoRenderer<T>` (the contract), `DesktopVideoRenderer` (local FFmpeg; mobile and web arms live in their encoder packages) |
| Entry points | `renderVideo`, `render`, `renderToSandbox`, `renderTemplate`, `RenderService`, `RenderConfig` |
| Host seams | `ShellMount`, `ShellFramePump`, `SetViewSize`, `ShellRunAsync`, `runAsyncDirectly`, `SandboxMount`, `SandboxFramePump`, `FrameEncoder` |
| Option parsing | `parseAspect`, `parseQuality`, `parseExportFormat`, `parsePosterTime`, `writeRenderProgress` |
| Capture | `FrameCaptureService`, `RepaintBoundaryCaptureService`, `RawFrame`, `RenderManifest`, `FrameCache` |
| Progress | `RenderProgress`, `RenderPhase`, `RenderProgressCallback`, `frameCountFor`, `runStage`, `runGuarded` |
| Sandboxes | `RenderSandbox`, `FileRenderSandbox`, `MemoryRenderSandbox`, `CaptureSink` |
| Encoding | `FfmpegRunner`, `FfmpegRunnerRegistry`, `ffmpegRunnerProvider`, `FfmpegVersion`, `WasmRuntime`, `createWasmRuntime` |
| Media resolving | `MediaResolver`, `mediaResolverProvider`, `NoMediaResolver`, `NetworkAllowlist`, `ResolverScope`, `WebClipDecoder` |
| Generative resolving | `GenerativeResolver`, `generativeResolverProvider`, `NoGenerativeResolver` |
| Analysis contracts | `SnapshotService`, `BeatDetectionService`, `FrequencyAnalyzer`, `FrameExtractionService`, `VideoProbeService` |
| Audio staging | `resolveAudioMix`, `ResolvedAudioMix`, `ResolvedAudioTrack`, `stageResolvedAudioToSandbox` |
| Collectors | `collectMediaSources`, `collectSnapshotSources`, `collectSnapshots`, `FadeBox` |

## `renderVideo`, the one capture entry

`renderVideo` is the whole render, in order: it resolves media, rasterizes any
`Snapshot` subtree, parses captions, analyses reactive audio, mounts the capture
shell, and loops the frames into `frames.rgba` plus a `manifest.json`. Everything
it needs is derived from the `Video` you hand it, so you pass no registry, no
media list, and no geometry.

A host supplies only the mechanics it alone can provide:

- `pumpWidget` mounts a tree.
- `pumpFrame` advances one frame.
- `setViewSize` points the view at the canvas.
- `runAsync` escapes fake async for real IO. It defaults to `runAsyncDirectly`
  for a host that already has a real event loop; a `flutter_test` host passes
  `tester.runAsync`.

Encoding is not part of it. The returned `RenderManifest` carries the complete
FFmpeg argument array for the caller to run.

The `parse*` helpers turn CLI define strings (`--aspect`, `--quality`,
`--format`, `--poster`) into the typed arguments `renderVideo` takes, and
`writeRenderProgress` writes the progress file a supervising process polls.

## Who imports it

- The capture harness the CLI generates for every render. It is regenerated per
  render and never committed, so it cannot drift from the CLI that writes it.
- `fluvie_mobile_encoder` and `fluvie_web_encoder`, which build on the shared
  capture loop and swap the encode edge.
- `fluvie_server`, which hosts renders behind an HTTP API.
- Your own code only when you build a custom render host or encoder backend.

If you only author videos and render with the CLI, you never need this import.

## Where to next

- [Exporting your video](../guides/exporting-your-video.md): formats, quality,
  and the render entry points in practice.
- [On-device mobile rendering](../guides/on-device-mobile-rendering.md) and
  [on-device web rendering](../guides/on-device-web-rendering.md): the two
  encoder backends built on this surface.
- [Cheatsheet](cheatsheet.md): the authoring surface on one page.
