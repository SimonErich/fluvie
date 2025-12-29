# VideoSequence

> **Low-level video sequence for custom pipelines**

`VideoSequence` is a lower-level widget for including external video files in a `VideoComposition`. It extends `Sequence` with video-specific properties for trimming and timing.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Examples](#examples)
- [When to Use](#when-to-use)
- [Related](#related)

---

## Overview

`VideoSequence` provides precise control over video timing in the rendering pipeline:

```dart
VideoSequence(
  assetPath: 'assets/intro.mp4',
  startFrame: 0,
  durationInFrames: 150,
  trimStartFrame: 30,
  trimDurationInFrames: 120,
)
```

### Use EmbeddedVideo Instead

For most use cases, [EmbeddedVideo](embedded-video.md) is recommended:

| Feature | VideoSequence | EmbeddedVideo |
|---------|--------------|---------------|
| Frame extraction | Manual | Automatic |
| Audio handling | Manual | Automatic |
| Preview support | Limited | Full |
| Caching | Manual | Automatic |
| API style | Low-level | High-level |

---

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `assetPath` | `String` | **required** | Path to video asset |
| `startFrame` | `int` | **required** | Frame to start in composition |
| `durationInFrames` | `int` | **required** | Duration in composition |
| `trimStartFrame` | `int` | `0` | Frame to start in source video |
| `trimDurationInFrames` | `int` | `0` | Duration to use from source (0 = to end) |
| `child` | `Widget` | `SizedBox()` | Optional child widget |

---

## Examples

### Basic Usage

```dart
VideoSequence(
  assetPath: 'assets/clip.mp4',
  startFrame: 0,
  durationInFrames: 150,  // 5 seconds at 30fps
)
```

### With Trimming

```dart
// Skip first 2 seconds, use next 4 seconds
VideoSequence(
  assetPath: 'assets/video.mp4',
  startFrame: 0,
  durationInFrames: 120,
  trimStartFrame: 60,   // Skip first 60 frames (2s at 30fps)
  trimDurationInFrames: 120,  // Use 120 frames (4s)
)
```

### In a Composition

```dart
VideoComposition(
  fps: 30,
  durationInFrames: 300,
  width: 1920,
  height: 1080,
  child: LayerStack(
    children: [
      // Video plays frames 0-150
      VideoSequence(
        assetPath: 'assets/intro.mp4',
        startFrame: 0,
        durationInFrames: 150,
      ),

      // Another video plays frames 120-270
      VideoSequence(
        assetPath: 'assets/main.mp4',
        startFrame: 120,
        durationInFrames: 150,
      ),
    ],
  ),
)
```

### Timing Diagram

```
Source Video: |0--------60--------120--------180| (frames)
              |   skip   |   use   |   ignore  |
                   ↑           ↑
              trimStartFrame  trimDurationInFrames

Composition:  |0--------------------150|
              |    VideoSequence      |
                   ↑                ↑
              startFrame    durationInFrames
```

---

## When to Use

### Use VideoSequence When:

- Building custom render pipelines
- Need direct control over RenderConfig
- Working with the low-level imperative API
- Integrating with existing video processing systems

### Use EmbeddedVideo When:

- Using the declarative API (`Video`, `Scene`)
- Want automatic frame extraction and caching
- Need preview playback support
- Want automatic audio handling
- Building typical video compositions

---

## Configuration Export

`VideoSequence` exports its configuration for the encoding pipeline:

```dart
// The toSequenceConfig() method is called internally
final config = videoSequence.toSequenceConfig();
// Returns SequenceConfig with video-specific data
```

This configuration is used by:
- `RenderService` for frame scheduling
- `FFmpegFilterGraphBuilder` for filter generation

---

## Related

- [EmbeddedVideo](embedded-video.md) - High-level alternative
- [Sequence](../core/sequence.md) - Base sequence widget
- [VideoComposition](../core/video-composition.md) - Composition root
- [Embedding Videos](../../embedding/videos.md) - Video guide
