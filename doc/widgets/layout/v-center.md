# VCenter

> **Video-aware Center with timing and fading**

`VCenter` extends Flutter's `Center` with video-specific properties like `startFrame`, `endFrame`, and fade transitions.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Examples](#examples)
- [Related](#related)

---

## Overview

`VCenter` centers its child widget while adding video timing capabilities:

```dart
VCenter(
  startFrame: 30,
  endFrame: 120,
  fadeInFrames: 15,
  child: Text('Centered Content'),
)
```

### When to Use

Use `VCenter` when you need:
- Centered content that appears/disappears at specific frames
- Centered content with fade in/out transitions
- A centered layout wrapper with video timing

---

## Properties

### Center Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `child` | `Widget` | **required** | Widget to center |
| `widthFactor` | `double?` | `null` | Width multiplier for constraints |
| `heightFactor` | `double?` | `null` | Height multiplier for constraints |

### Video Timing Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `startFrame` | `int?` | `null` | Frame to become visible |
| `endFrame` | `int?` | `null` | Frame to become invisible |
| `fadeInFrames` | `int` | `0` | Fade-in duration in frames |
| `fadeOutFrames` | `int` | `0` | Fade-out duration in frames |
| `fadeInCurve` | `Curve` | `easeOut` | Fade-in easing |
| `fadeOutCurve` | `Curve` | `easeIn` | Fade-out easing |

---

## Examples

### Basic Centered Text

```dart
VCenter(
  child: Text(
    'Hello, World!',
    style: TextStyle(fontSize: 72, color: Colors.white),
  ),
)
```

### With Fade Animation

```dart
VCenter(
  startFrame: 30,
  fadeInFrames: 20,
  fadeOutFrames: 20,
  endFrame: 120,
  child: AnimatedText(
    'Welcome',
    style: TextStyle(fontSize: 64),
  ),
)
```

### Centered Column

```dart
VCenter(
  startFrame: 0,
  fadeInFrames: 25,
  child: VColumn(
    spacing: 20,
    stagger: StaggerConfig.slideUp(delay: 12),
    children: [
      Text('2024', style: yearStyle),
      Text('YOUR YEAR', style: subtitleStyle),
      Text('IN REVIEW', style: subtitleStyle),
    ],
  ),
)
```

### With Size Constraints

Use `widthFactor` and `heightFactor` to constrain the centered area:

```dart
VCenter(
  widthFactor: 0.8,   // Use 80% of available width
  heightFactor: 0.6,  // Use 60% of available height
  startFrame: 0,
  fadeInFrames: 30,
  child: ContentWidget(),
)
```

### In a Scene

```dart
Scene(
  durationInFrames: 150,
  background: Background.solid(Colors.black),
  children: [
    VCenter(
      startFrame: 0,
      fadeInFrames: 30,
      fadeOutFrames: 30,
      child: VColumn(
        spacing: 15,
        children: [
          Text(
            'Welcome',
            style: TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            'to your story',
            style: TextStyle(
              fontSize: 36,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    ),
  ],
)
```

### Multiple Centered Layers

```dart
LayerStack(
  children: [
    Layer.background(
      child: AnimatedGradient(),
    ),

    // First centered content
    VCenter(
      startFrame: 0,
      endFrame: 60,
      fadeInFrames: 15,
      fadeOutFrames: 15,
      child: Text('Part 1'),
    ),

    // Second centered content
    VCenter(
      startFrame: 45,
      endFrame: 120,
      fadeInFrames: 15,
      fadeOutFrames: 15,
      child: Text('Part 2'),
    ),
  ],
)
```

---

## Comparison with Center

| Feature | Center | VCenter |
|---------|--------|---------|
| Centers child | Yes | Yes |
| Size factors | Yes | Yes |
| Time-based visibility | No | Yes |
| Fade transitions | No | Yes |

---

## Related

- [VColumn](v-column.md) - Column with timing
- [VRow](v-row.md) - Row with timing
- [VPadding](v-padding.md) - Padding with timing
- [VPositioned](v-positioned.md) - Positioned with timing
