# Architecture

> **The dual-engine model that powers Fluvie**

Fluvie combines Flutter's powerful widget system with FFmpeg's video encoding capabilities. This page explains how these components work together.

## Table of Contents

- [Overview](#overview)
- [The Four Layers](#the-four-layers)
- [Data Flow](#data-flow)
- [Why This Architecture?](#why-this-architecture)

---

## Overview

Fluvie is built on a dual-engine architecture:

```
┌─────────────────────────────────────────────────────────────────┐
│                         FLUVIE                                   │
│                                                                  │
│  ┌─────────────────────┐      ┌─────────────────────────────┐   │
│  │    Flutter Engine    │      │       FFmpeg Engine         │   │
│  │                      │      │                             │   │
│  │  • Widget system     │      │  • Video encoding           │   │
│  │  • Layout & styling  │      │  • Audio mixing             │   │
│  │  • Animation curves  │      │  • Filter processing        │   │
│  │  • Frame rasterization│     │  • Format conversion        │   │
│  │                      │      │                             │   │
│  └──────────┬───────────┘      └──────────────┬──────────────┘   │
│             │                                  │                  │
│             │     Raw Frame Bytes              │                  │
│             └──────────────────────────────────┘                  │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
```

**Flutter** handles everything visual:
- Building the widget tree
- Computing layouts
- Rasterizing each frame to pixels

**FFmpeg** handles everything video:
- Encoding frames into video codec (H.264, VP9, etc.)
- Mixing audio tracks
- Writing the final container (MP4, WebM, etc.)

---

## The Four Layers

Fluvie is organized into four distinct layers, each with a specific responsibility:

### 1. Presentation Layer

**Location:** `lib/src/presentation/`

The presentation layer contains all the Flutter widgets you use to build videos:

| Component | Description |
|-----------|-------------|
| `VideoComposition` | Root widget that defines video properties |
| `Scene` | Time-bounded section of video |
| `Sequence` | Basic timing container |
| `TimeConsumer` | Frame-based animation driver |
| `Layer` / `LayerStack` | Z-indexed compositing |
| `AudioTrack` | Audio attachment |

**Key insight:** These are standard Flutter widgets! They follow Flutter's composition model and can be combined with any Flutter widget.

```dart
// Presentation layer widgets
VideoComposition(
  fps: 30,
  durationInFrames: 150,
  child: LayerStack(
    children: [
      Layer.background(child: GradientBackground()),
      Layer(child: AnimatedTitle()),
    ],
  ),
)
```

### 2. Domain Layer

**Location:** `lib/src/domain/`

The domain layer contains serializable configuration models. These represent the video structure in a format that can be passed between layers:

| Component | Description |
|-----------|-------------|
| `RenderConfig` | Complete video configuration |
| `TimelineConfig` | FPS, duration, dimensions |
| `SequenceConfig` | Individual sequence timing |
| `AudioTrackConfig` | Audio file and timing |
| `EncodingConfig` | Quality and format options |

**Key insight:** Domain models are pure data. They can be serialized to JSON, stored, or transmitted.

```dart
// Domain layer models (auto-generated from widgets)
RenderConfig(
  timeline: TimelineConfig(
    fps: 30,
    durationInFrames: 150,
    width: 1920,
    height: 1080,
  ),
  sequences: [...],
  audioTracks: [...],
)
```

### 3. Capture Layer

**Location:** `lib/src/capture/`

The capture layer extracts raw pixel data from Flutter's rendering pipeline:

| Component | Description |
|-----------|-------------|
| `FrameSequencer` | Captures frames from RepaintBoundary |
| `RenderModeProvider` | Context for render vs preview mode |
| `FrameReadyNotifier` | Tracks async operations |

**Key insight:** Flutter renders to a `RepaintBoundary`, which is then captured as raw RGBA bytes.

```dart
// Capture layer operation
final boundary = boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
final image = await boundary.toImage(pixelRatio: devicePixelRatio);
final byteData = await image.toByteData(format: ImageByteFormat.rawRgba);
```

### 4. Encoding Layer

**Location:** `lib/src/encoding/`

The encoding layer manages FFmpeg and produces the final video:

| Component | Description |
|-----------|-------------|
| `VideoEncoderService` | Manages FFmpeg encoding session |
| `FFmpegFilterGraphBuilder` | Builds complex filter graphs |
| `FFmpegProvider` | Platform-specific FFmpeg interface |
| `VideoProbeService` | Extracts video metadata |
| `FrameExtractionService` | Extracts frames from video files |

**Key insight:** FFmpeg receives raw frames via stdin and outputs an encoded video file.

```dart
// Encoding layer operation
final session = await encoderService.startEncoding(
  config: renderConfig,
  outputPath: 'output.mp4',
);

// Stream frames to FFmpeg
for (final frameBytes in frames) {
  session.sink.add(frameBytes);
}

await session.close();
```

---

## Data Flow

Here's how data flows through all four layers during video rendering:

```
┌─────────────────────────────────────────────────────────────────┐
│  1. PRESENTATION LAYER                                          │
│                                                                  │
│     Your widgets define the video structure                      │
│     VideoComposition → Scene → Widgets                           │
│                                                                  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ createConfigFromContext()
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  2. DOMAIN LAYER                                                 │
│                                                                  │
│     Widget tree is converted to RenderConfig                     │
│     (serializable data structure)                                │
│                                                                  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ For each frame...
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  3. CAPTURE LAYER                                                │
│                                                                  │
│     ┌─────────────┐     ┌─────────────────────────────────────┐ │
│     │  Frame 0    │────▶│  Pump widget tree                   │ │
│     │             │     │  Wait for rasterization             │ │
│     │             │     │  Capture from RepaintBoundary       │ │
│     │             │     │  Return raw RGBA bytes              │ │
│     └─────────────┘     └───────────────────────┬─────────────┘ │
│                                                  │               │
│     ┌─────────────┐                              │               │
│     │  Frame 1    │──────────────────────────────┤               │
│     └─────────────┘                              │               │
│                                                  │               │
│     ┌─────────────┐                              │               │
│     │  Frame N    │──────────────────────────────┤               │
│     └─────────────┘                              │               │
│                                                  ▼               │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ Stream of frame bytes
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  4. ENCODING LAYER                                               │
│                                                                  │
│     ┌────────────────────────────────────────────────────────┐  │
│     │  FFmpeg Process                                         │  │
│     │                                                         │  │
│     │  Inputs:                                                │  │
│     │    - Frame stream (stdin)                               │  │
│     │    - Audio files                                        │  │
│     │    - Embedded videos                                    │  │
│     │                                                         │  │
│     │  Filter Graph:                                          │  │
│     │    [frames] → fps → format → [v_out]                    │  │
│     │    [audio1] + [audio2] → amix → [a_out]                 │  │
│     │                                                         │  │
│     │  Output:                                                │  │
│     │    - Encoded video file (MP4)                           │  │
│     │                                                         │  │
│     └────────────────────────────────────────────────────────┘  │
│                                                                  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │  output.mp4     │
                    │  (Final Video)  │
                    └─────────────────┘
```

---

## Why This Architecture?

### Why Flutter?

1. **Rich widget ecosystem** - Use any Flutter widget in your videos
2. **Familiar development model** - If you know Flutter, you know Fluvie
3. **Hot reload for preview** - Rapid iteration during development
4. **Cross-platform** - Same code works on Linux, macOS, Windows, Web
5. **Declarative UI** - Describe what you want, not how to draw it

### Why FFmpeg?

1. **Industry standard** - Battle-tested video encoding
2. **Codec support** - H.264, H.265, VP9, AV1, and more
3. **Audio mixing** - Complex audio graphs with fades and ducking
4. **Filter graphs** - Post-processing effects if needed
5. **Format support** - MP4, WebM, MOV, and more

### Why Separate Them?

1. **Each engine does what it's best at** - Flutter renders, FFmpeg encodes
2. **Testability** - Layers can be tested independently
3. **Flexibility** - Swap FFmpeg providers per platform
4. **Performance** - Raw frame streaming is efficient
5. **Reliability** - Both engines are mature and stable

---

## Integration Points

### RenderService

The `RenderService` class is the main integration point that orchestrates all layers:

```dart
// lib/src/integration/render_service.dart

class RenderService {
  /// Creates RenderConfig from widget tree
  RenderConfig createConfigFromContext(BuildContext context);

  /// Executes the full render pipeline
  Future<String> execute({
    required BuildContext context,
    required String outputPath,
    required Future<void> Function(int frame) onFrameUpdate,
    void Function(double progress)? onProgress,
  });
}
```

### FFmpegProvider

Platform-specific FFmpeg integration is abstracted behind the `FFmpegProvider` interface:

```dart
// Available providers
ProcessFFmpegProvider  // Desktop: runs FFmpeg as a process
WasmFFmpegProvider     // Web: uses ffmpeg.wasm
// Custom provider      // Mobile: use FFmpegKit
```

---

## Source Code Reference

| Layer | Key Files |
|-------|-----------|
| Presentation | `lib/src/presentation/video_composition.dart`, `sequence.dart`, `time_consumer.dart` |
| Domain | `lib/src/domain/render_config.dart`, `encoding_settings.dart` |
| Capture | `lib/src/capture/frame_sequencer.dart` |
| Encoding | `lib/src/encoding/video_encoder_service.dart`, `ffmpeg_filter_graph_builder.dart` |
| Integration | `lib/src/integration/render_service.dart` |

---

## Related Documentation

- [Rendering Pipeline](rendering-pipeline.md) - Detailed frame-by-frame walkthrough
- [Custom FFmpeg Provider](../extending/custom-ffmpeg-provider.md) - Platform integration
- [Encoding Settings](../advanced/encoding-settings.md) - Output configuration
