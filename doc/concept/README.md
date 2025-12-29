# Core Concepts

> **Understanding how Fluvie works under the hood**

Before diving into building videos, it helps to understand the fundamental concepts that make Fluvie work. This section covers the architecture, animation model, and rendering pipeline.

## Table of Contents

- [Architecture](architecture.md) - The dual-engine model
- [Frame-Based Animation](frame-based-animation.md) - Why frames matter
- [Rendering Pipeline](rendering-pipeline.md) - From widgets to video
- [Preview vs Render Mode](two-modes.md) - Development workflow

---

## Quick Overview

### The Big Picture

Fluvie combines two powerful technologies:

1. **Flutter** - Provides the widget system, rendering engine, and developer experience
2. **FFmpeg** - Handles video encoding, audio mixing, and format conversion

```
┌─────────────────────────────────────────────────────────┐
│                    Your Code                             │
│                                                          │
│   Video(                                                 │
│     scenes: [                                            │
│       Scene(children: [...]),                            │
│       Scene(children: [...]),                            │
│     ],                                                   │
│   )                                                      │
│                                                          │
└────────────────────────┬────────────────────────────────┘
                         │
           ┌─────────────▼─────────────┐
           │      Flutter Engine       │
           │   (Skia/Impeller)         │
           │                           │
           │  Rasterizes each frame    │
           └─────────────┬─────────────┘
                         │
           ┌─────────────▼─────────────┐
           │        FFmpeg             │
           │                           │
           │  Encodes frames + audio   │
           │  into final video file    │
           └─────────────┬─────────────┘
                         │
           ┌─────────────▼─────────────┐
           │     Output Video          │
           │     (MP4, WebM, etc.)     │
           └───────────────────────────┘
```

### Frame-Based Thinking

Unlike traditional Flutter animations that run on wall-clock time, Fluvie animations are tied to **frame numbers**. This is crucial for video:

- Frame 0 is always the start of your video
- At 30 fps, frame 30 is exactly 1 second into the video
- Animations are deterministic and reproducible

```dart
// Instead of Duration, use frames
Scene(
  durationInFrames: 90,  // 3 seconds at 30fps
  children: [
    AnimatedText.slideUpFade(
      'Hello',
      startFrame: 0,   // Start immediately
      duration: 30,    // Animate over 1 second
    ),
  ],
)
```

### Two Operating Modes

Fluvie operates in two modes:

| Mode | Purpose | How It Works |
|------|---------|--------------|
| **Preview** | Development | Plays at real-time speed with audio |
| **Render** | Export | Captures frames deterministically |

In preview mode, you get instant feedback. In render mode, every frame is captured perfectly, regardless of how long each frame takes to render.

---

## Key Concepts to Understand

### 1. Compositions are Widget Trees

A Fluvie video is just a Flutter widget tree. Everything you know about Flutter widgets applies:

```dart
Video(                          // Root widget
  scenes: [
    Scene(                      // Container widget
      children: [
        VStack(                 // Layout widget
          children: [
            AnimatedText(...),  // Content widget
            Image.asset(...),   // Standard Flutter widget
          ],
        ),
      ],
    ),
  ],
)
```

### 2. Time is Measured in Frames

Every timing value is expressed in frames:

```dart
Scene(
  durationInFrames: 150,           // Scene duration: 150 frames
  fadeInFrames: 15,      // Fade in over 15 frames
  fadeOutFrames: 15,     // Fade out over 15 frames
  children: [
    VPositioned(
      startFrame: 30,    // Appear at frame 30
      endFrame: 120,     // Disappear at frame 120
      child: ...,
    ),
  ],
)
```

### 3. State Comes from Frame Number

Instead of stateful widgets, Fluvie uses the current frame number to derive state:

```dart
TimeConsumer(
  builder: (context, frame, progress) {
    // frame: current frame number (0, 1, 2, ...)
    // progress: 0.0 to 1.0 through the composition

    final color = Color.lerp(Colors.blue, Colors.red, progress)!;
    return Container(color: color);
  },
)
```

### 4. Audio is Synchronized

Audio tracks are precisely aligned to frame numbers:

```dart
AudioTrack(
  source: AudioSource.asset('music.mp3'),
  startFrame: 0,         // Start with the video
  durationInFrames: 300, // Play for 300 frames
  fadeInFrames: 30,      // Fade in over 30 frames
  fadeOutFrames: 30,     // Fade out over 30 frames
  child: ...,
)
```

---

## Next Steps

Dive deeper into each concept:

1. **[Architecture](architecture.md)** - Learn about the four layers (Presentation, Domain, Capture, Encoding)

2. **[Frame-Based Animation](frame-based-animation.md)** - Understand why frame-based timing is essential for video

3. **[Rendering Pipeline](rendering-pipeline.md)** - Follow a frame from widget to video file

4. **[Preview vs Render Mode](two-modes.md)** - Learn how to develop and export efficiently

---

## Related Documentation

- [Getting Started](../getting-started/README.md) - Installation and first video
- [TimeConsumer Widget](../widgets/core/time-consumer.md) - Frame-based state
- [Encoding Settings](../advanced/encoding-settings.md) - Video output options
