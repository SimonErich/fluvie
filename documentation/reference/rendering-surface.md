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

The barrels share value types such as time and export choices. The authoring
import keeps composition code declarative; host machinery lives on the rendering
surface.

## What lives here

| Group | Surface |
| --- | --- |
| Renderers | `RequestVideoRenderer<T>`, `VideoRenderRequest`, `VideoRenderer<T>` (legacy adapter contract), `DesktopVideoRenderer` (local FFmpeg; mobile and web arms live in their encoder packages) |
| Preparation | `CompositionSession`, `PreparedComposition`: mounted timing, resources, authored output settings and embedded audio plans |
| Cancellation | `RenderCancellation`, `RenderCancelledException`: caller-owned cooperative cancellation |
| Entry points | `runFluvieRender`, `RenderInvocation`, `RenderHostContext`, `renderVideo`, `render`, `renderToSandbox`, `renderTemplate`, `RenderService`, `RenderConfig` |
| Host seams | `ShellMount`, `ShellFramePump`, `SetViewSize`, `ShellRunAsync`, `runAsyncDirectly`, `SandboxMount`, `SandboxFramePump`, `FrameEncoder` |
| Option parsing | `parseAspect`, `parseQuality`, `parseExportFormat`, `parsePosterTime`, `writeRenderProgress` |
| Capture | `FrameCaptureService`, `RepaintBoundaryCaptureService`, `RawFrame`, `RenderManifest`, `FrameCache` |
| Progress | `RenderProgress`, `RenderPhase`, `RenderProgressCallback`, `frameCountFor`, `runStage`, `runGuarded` |
| Sandboxes | `RenderSandbox`, `FileRenderSandbox`, `MemoryRenderSandbox`, `CaptureSink` |
| Encoding | `FfmpegRunner`, `FfmpegRunnerRegistry`, `ffmpegRunnerProvider`, `FfmpegVersion`, `WasmRuntime`, `createWasmRuntime` |
| Media resolving | `MediaResolver`, `mediaResolverProvider`, `NoMediaResolver`, `NetworkAllowlist`, `ResolverScope`, `WebClipDecoder` |
| Generative resolving | `GenerativeResolver`, `generativeResolverProvider`, `NoGenerativeResolver` |
| Analysis contracts | `SnapshotService`, `BeatDetectionService`, `FrequencyAnalyzer`, `PcmDecoder`, `SharedPcmDecoder`, `FrameExtractionService`, `FrameExtractionCacheIdentity`, `VideoProbeService` |
| Audio staging | `resolveAudioMix`, `ResolvedAudioMix`, `ResolvedAudioTrack`, `stageResolvedAudioToSandbox` |
| Collectors | `compositionVideo`, `collectMediaSources`, `collectSnapshotSources`, `collectSnapshots`, `FadeBox` |

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

- The minimal cached adapter the CLI prepares outside the consumer project.
  Shared capture behavior stays in the resolved package's `runFluvieRender`.
- `fluvie_mobile_encoder` and `fluvie_web_encoder`, which build on the shared
  capture loop and swap the encode edge.
- `fluvie_server`, which hosts renders behind an HTTP API.
- Your own code only when you build a custom render host or encoder backend.

If you only author videos and render with the CLI, you never need this import.

For custom review hosts, `runFluvieRender(video: video, host: host,
videoFactory: buildVideo)` can invoke the authored entry again during a
determinism review. The factory is optional: a video-only host still checks fresh
widget state. Both paths use a new session, resolver and snapshot preparation,
and unmount the tree before releasing its resources. See
[reviewing a video](../guides/reviewing-a-video.md) for report fields and limits.

## Receive one complete render request

Custom adapters implement `RequestVideoRenderer<T>` alongside `VideoRenderer<T>`
to receive exact canvas dimensions, capture range, export and quality overrides,
poster selection, audio policy, progress and cancellation. The default hosts use
the complete-request interface when it is available. Existing legacy adapters
remain compatible; unsupported options must fail visibly rather than disappear.

`startFrame` is an authored frame. `frameCount` counts output pictures without
shortening the composition's timing. `posterFrame` is relative to the output:
the example below captures authored frames 120 through 179 and picks authored
frame 135 for its poster.

<!-- code-excerpt "examples/gallery/lib/snippets/render_request_snippets.dart (render-request)" -->
```dart
import 'package:flutter/widgets.dart' show Widget;
import 'package:fluvie/rendering.dart' show RenderCancellation, VideoRenderRequest;

/// Request two authored seconds, starting four seconds into a composition.
VideoRenderRequest excerptRequest(Widget composition, RenderCancellation cancellation) =>
    VideoRenderRequest(
      composition: composition,
      width: 480,
      height: 270,
      startFrame: 120,
      frameCount: 60,
      posterFrame: 15,
      cancellation: cancellation,
    );
```

An adapter declares `RenderCapabilities`, calls `request.validateCapabilities`
before capture, and resolves mounted authored defaults through
`PreparedComposition.resolveRequest`. The [capability registry](render-capabilities.md)
lists backend settings and environmental requirements. Keep exact dimensions;
an arbitrary canvas does not need to be rounded to an aspect preset.

`CompositionSession.prepare` mounts ordinary custom widgets and discovers their
clips, images, snapshots and authored `Video`. Its `prepared` value provides the
same immutable facts to export policy, audio staging and clip decoding. Continue
to call `prepareFrame` before each capture; prepared metadata does not mean every
picture has been decoded. Dispose the session and its host-owned resolver at the
end of the operation.

Pass a `RenderCancellation` and call `cancel()` to stop work. Built-in preparation,
capture and native decoding observe it; custom encoders must also connect
`whenCancelled` to their owned process or device operation. Cancellation throws
`RenderCancelledException` after cleanup instead of reporting an encode failure.

## Inspecting a wrapped composition

`compositionVideo` is a small declaration-level helper for hosts. It unwraps a
`Video`, proxy widgets, and single-child render wrappers; it returns `null` for
an opaque custom widget or a tree without a directly declared video. Full
preparation mounts custom widgets to discover their resources.

<!-- code-excerpt "examples/gallery/lib/snippets/render_host_snippets.dart (composition-video)" -->
```dart
import 'package:flutter/widgets.dart' show Widget;
import 'package:fluvie/fluvie.dart' show Video;
import 'package:fluvie/rendering.dart' show compositionVideo;

/// Inspect a declared Video under transparent single-child wrappers.
Video? findAuthoredVideo(Widget composition) => compositionVideo(composition);
```

## Where to next

- [Exporting your video](../guides/exporting-your-video.md): formats, quality,
  and the render entry points in practice.
- [On-device mobile rendering](../guides/on-device-mobile-rendering.md) and
  [on-device web rendering](../guides/on-device-web-rendering.md): the two
  encoder backends built on this surface.
- [Cheatsheet](cheatsheet.md): the authoring surface on one page.
- [Render capabilities](render-capabilities.md): supported choices and requirements.
