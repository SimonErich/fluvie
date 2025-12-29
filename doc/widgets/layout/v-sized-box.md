# VSizedBox

> **Video-aware SizedBox with timing and fading**

`VSizedBox` extends Flutter's `SizedBox` with video-specific properties like `startFrame`, `endFrame`, and fade transitions.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Constructors](#constructors)
- [Examples](#examples)
- [Related](#related)

---

## Overview

`VSizedBox` constrains its child to a specific size while supporting video timing:

```dart
VSizedBox(
  width: 200,
  height: 100,
  startFrame: 30,
  fadeInFrames: 15,
  child: Text('Sized Content'),
)
```

### When to Use

Use `VSizedBox` when you need:
- Fixed-size content that appears/disappears at specific frames
- Sized content with fade in/out transitions
- A size constraint wrapper with video timing
- Spacers that appear/disappear

---

## Properties

### SizedBox Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `child` | `Widget?` | `null` | Widget to size |
| `width` | `double?` | `null` | Fixed width |
| `height` | `double?` | `null` | Fixed height |

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

## Constructors

### Default Constructor

```dart
VSizedBox(
  width: 200,
  height: 100,
  child: Content(),
)
```

### VSizedBox.fromSize

Create from a `Size` object:

```dart
VSizedBox.fromSize(
  size: Size(200, 100),
  child: Content(),
)
```

### VSizedBox.expand

Expand to fill available space:

```dart
VSizedBox.expand(
  startFrame: 30,
  fadeInFrames: 15,
  child: FullScreenContent(),
)
```

### VSizedBox.shrink

Shrink to minimum size (0x0):

```dart
VSizedBox.shrink(
  startFrame: 30,
  fadeInFrames: 15,
  child: CollapsedContent(),
)
```

### VSizedBox.square

Create a square box:

```dart
VSizedBox.square(
  dimension: 200,
  startFrame: 0,
  fadeInFrames: 20,
  child: SquareContent(),
)
```

---

## Examples

### Basic Sized Box

```dart
VSizedBox(
  width: 300,
  height: 200,
  child: Container(
    color: Colors.blue,
    child: Center(child: Text('300x200')),
  ),
)
```

### With Timing

```dart
VSizedBox(
  width: 400,
  height: 300,
  startFrame: 30,
  endFrame: 120,
  fadeInFrames: 20,
  fadeOutFrames: 20,
  child: Image.asset('assets/photo.jpg', fit: BoxFit.cover),
)
```

### Square Image Frame

```dart
VSizedBox.square(
  dimension: 250,
  startFrame: 15,
  fadeInFrames: 20,
  child: ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: Image.asset('assets/profile.jpg', fit: BoxFit.cover),
  ),
)
```

### Expanding Content

```dart
VSizedBox.expand(
  startFrame: 0,
  fadeInFrames: 30,
  child: Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.purple, Colors.blue],
      ),
    ),
  ),
)
```

### Timed Spacer

Use `VSizedBox` without a child as a timed spacer:

```dart
VColumn(
  children: [
    Text('Before'),
    VSizedBox(
      height: 50,
      startFrame: 30,  // Spacer appears at frame 30
    ),
    Text('After'),
  ],
)
```

### Card Grid

```dart
VRow(
  mainAxisAlignment: MainAxisAlignment.center,
  spacing: 20,
  stagger: StaggerConfig.scale(delay: 10),
  children: [
    VSizedBox.square(
      dimension: 150,
      child: Card(child: Icon(Icons.music_note)),
    ),
    VSizedBox.square(
      dimension: 150,
      child: Card(child: Icon(Icons.favorite)),
    ),
    VSizedBox.square(
      dimension: 150,
      child: Card(child: Icon(Icons.star)),
    ),
  ],
)
```

### Constrained Content Area

```dart
Scene(
  durationInFrames: 180,
  background: Background.solid(Colors.black),
  children: [
    VCenter(
      child: VSizedBox(
        width: 800,
        height: 600,
        startFrame: 0,
        fadeInFrames: 30,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(20),
          ),
          child: ContentWidget(),
        ),
      ),
    ),
  ],
)
```

---

## Timing Behavior

**Note:** `VSizedBox` only wraps with timing when `startFrame` or `endFrame` is specified. Without timing properties, it behaves exactly like a regular `SizedBox`.

```dart
// No timing wrapper - behaves like SizedBox
VSizedBox(
  width: 200,
  height: 100,
  child: Content(),
)

// Has timing wrapper - video-aware
VSizedBox(
  width: 200,
  height: 100,
  startFrame: 30,  // Triggers timing behavior
  child: Content(),
)
```

---

## Comparison with SizedBox

| Feature | SizedBox | VSizedBox |
|---------|----------|-----------|
| Fixed dimensions | Yes | Yes |
| Expand/shrink | Yes | Yes |
| Square constructor | Yes | Yes |
| Time-based visibility | No | Yes |
| Fade transitions | No | Yes |

---

## Related

- [VPadding](v-padding.md) - Padding with timing
- [VCenter](v-center.md) - Center with timing
- [VPositioned](v-positioned.md) - Positioned with timing
