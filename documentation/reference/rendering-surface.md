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
| Entry points | `render`, `renderToSandbox`, `renderTemplate`, `RenderService`, `RenderConfig` |
| Host seams | `ShellMount`, `ShellFramePump`, `SandboxMount`, `SandboxFramePump`, `FrameEncoder` |
| Capture | `FrameCaptureService`, `RepaintBoundaryCaptureService`, `RawFrame`, `RenderManifest`, `FrameCache` |
| Progress | `RenderProgress`, `RenderPhase`, `RenderProgressCallback`, `frameCountFor`, `runStage`, `runGuarded` |
| Sandboxes | `RenderSandbox`, `FileRenderSandbox`, `MemoryRenderSandbox`, `CaptureSink` |
| Encoding | `FfmpegRunner`, `FfmpegRunnerRegistry`, `ffmpegRunnerProvider`, `FfmpegVersion`, `WasmRuntime`, `createWasmRuntime` |
| Media resolving | `MediaResolver`, `mediaResolverProvider`, `NoMediaResolver`, `NetworkAllowlist`, `ResolverScope`, `WebClipDecoder` |
| Generative resolving | `GenerativeResolver`, `generativeResolverProvider`, `NoGenerativeResolver` |
| Analysis contracts | `SnapshotService`, `BeatDetectionService`, `FrequencyAnalyzer`, `FrameExtractionService`, `VideoProbeService` |
| Audio staging | `resolveAudioMix`, `ResolvedAudioMix`, `ResolvedAudioTrack`, `stageResolvedAudioToSandbox` |
| Collectors | `collectMediaSources`, `collectSnapshotSources`, `collectSnapshots`, `FadeBox` |

## Who imports it

- The capture harness `fluvie init` scaffolds (and every example app's copy).
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
