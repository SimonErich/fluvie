# Sequence

> **Basic timing container for video content**

`Sequence` is a fundamental building block that wraps content with timing information. It's used internally by many Fluvie widgets and can be used directly for precise timing control.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Examples](#examples)
- [Specialized Sequences](#specialized-sequences)
- [Related](#related)

---

## Overview

`Sequence` defines when content appears in the timeline:

```dart
Sequence(
  startFrame: 30,       // Appear at frame 30
  durationInFrames: 60, // Visible for 60 frames
  child: MyContent(),
)
```

### When to Use

Use `Sequence` when:
- You need precise frame-level timing
- Working with `VideoComposition` directly
- Building custom timing systems

Use `VPositioned` or `Layer` instead when:
- You want fade effects
- Working with the `Video` widget
- Need positioning as well as timing

---

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `startFrame` | `int` | `0` | Frame where content becomes visible |
| `durationInFrames` | `int` | **required** | How many frames content is visible |
| `child` | `Widget` | **required** | Content to display |

---

## Examples

### Basic Timing

```dart
LayerStack(
  children: [
    // First element: frames 0-60
    Sequence(
      startFrame: 0,
      durationInFrames: 60,
      child: Text('First'),
    ),

    // Second element: frames 30-120
    Sequence(
      startFrame: 30,
      durationInFrames: 90,
      child: Text('Second'),
    ),

    // Third element: frames 60-150
    Sequence(
      startFrame: 60,
      durationInFrames: 90,
      child: Text('Third'),
    ),
  ],
)
```

### Visibility Timeline

```
Frame:    0    30    60    90   120   150
          |     |     |     |     |     |
First:    ███████████████
Second:         ███████████████████████
Third:                ████████████████████████
```

### With Other Widgets

Combine with other Fluvie widgets:

```dart
Sequence(
  startFrame: 30,
  durationInFrames: 120,
  child: AnimatedProp(
    animation: PropAnimation.fadeIn(),
    duration: 30,
    child: MyContent(),
  ),
)
```

### In VideoComposition

```dart
VideoComposition(
  fps: 30,
  durationInFrames: 180,
  child: Stack(
    children: [
      // Background always visible
      Container(color: Colors.blue),

      // Title visible frames 0-90
      Sequence(
        startFrame: 0,
        durationInFrames: 90,
        child: Center(child: Text('Title')),
      ),

      // Subtitle visible frames 60-180
      Sequence(
        startFrame: 60,
        durationInFrames: 120,
        child: Positioned(
          bottom: 50,
          child: Text('Subtitle'),
        ),
      ),
    ],
  ),
)
```

---

## Specialized Sequences

Fluvie provides specialized sequence widgets for specific content types:

### VideoSequence

For embedding video files:

```dart
VideoSequence(
  assetPath: 'assets/video/clip.mp4',
  startFrame: 30,
  durationInFrames: 150,
  trimStartFrame: 60,  // Start from frame 60 in source video
)
```

See [VideoSequence](../media/video-sequence.md) for details.

### TextSequence

For text with timing:

```dart
TextSequence(
  text: 'Hello World',
  startFrame: 0,
  durationInFrames: 90,
  style: TextStyle(fontSize: 48),
)
```

### How They Relate

```
Sequence (base)
├── VideoSequence (video content)
└── TextSequence (text content)
```

All specialized sequences extend the base `Sequence` behavior with type-specific features.

---

## Internal Representation

Sequences are converted to `SequenceConfig` during rendering:

```dart
// What you write
Sequence(
  startFrame: 30,
  durationInFrames: 60,
  child: MyWidget(),
)

// What's stored in RenderConfig
SequenceConfig(
  startFrame: 30,
  durationInFrames: 60,
  type: SequenceType.base,
)
```

This config is used by:
- `RenderService` for frame scheduling
- `FFmpegFilterGraphBuilder` for filter timing

---

## Comparison with Other Timing Widgets

| Widget | Timing | Fading | Positioning |
|--------|--------|--------|-------------|
| `Sequence` | Yes | No | No |
| `Layer` | Yes | Yes | No |
| `VPositioned` | Yes | Yes | Yes |

### When to Use Each

```dart
// Just timing
Sequence(
  startFrame: 30,
  durationInFrames: 60,
  child: Content(),
)

// Timing + fading
Layer(
  startFrame: 30,
  endFrame: 90,
  fadeInFrames: 15,
  fadeOutFrames: 15,
  child: Content(),
)

// Timing + fading + positioning
VPositioned(
  left: 100,
  top: 200,
  startFrame: 30,
  endFrame: 90,
  fadeInFrames: 15,
  child: Content(),
)
```

---

## Related

- [Layer](../layout/layer.md) - Sequence with fading
- [VPositioned](../layout/v-positioned.md) - Sequence with positioning
- [VideoSequence](../media/video-sequence.md) - Video content
- [TimeConsumer](time-consumer.md) - Frame-based animation
