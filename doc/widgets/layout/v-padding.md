# VPadding

> **Video-aware Padding with timing and fading**

`VPadding` extends Flutter's `Padding` with video-specific properties like `startFrame`, `endFrame`, and fade transitions.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Constructors](#constructors)
- [Examples](#examples)
- [Related](#related)

---

## Overview

`VPadding` adds padding around its child while supporting video timing:

```dart
VPadding(
  padding: EdgeInsets.all(20),
  startFrame: 30,
  fadeInFrames: 15,
  child: Text('Padded Content'),
)
```

### When to Use

Use `VPadding` when you need:
- Padded content that appears/disappears at specific frames
- Padded content with fade in/out transitions
- A padding wrapper with video timing

---

## Properties

### Padding Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `child` | `Widget` | **required** | Widget to pad |
| `padding` | `EdgeInsetsGeometry` | **required** | Amount of padding |

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
VPadding(
  padding: EdgeInsets.all(20),
  child: Content(),
)
```

### VPadding.all

Uniform padding on all sides:

```dart
VPadding.all(
  20,
  child: Content(),
)
```

### VPadding.symmetric

Symmetric horizontal and vertical padding:

```dart
VPadding.symmetric(
  horizontal: 40,
  vertical: 20,
  child: Content(),
)
```

### VPadding.only

Padding on specific sides:

```dart
VPadding.only(
  left: 20,
  top: 40,
  right: 20,
  bottom: 60,
  child: Content(),
)
```

---

## Examples

### Basic Padding

```dart
VPadding(
  padding: EdgeInsets.all(50),
  child: Container(
    color: Colors.blue,
    child: Text('Padded Box'),
  ),
)
```

### With Timing

```dart
VPadding(
  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
  startFrame: 30,
  endFrame: 120,
  fadeInFrames: 15,
  fadeOutFrames: 15,
  child: Text(
    'This text appears with padding at frame 30',
    style: TextStyle(fontSize: 24),
  ),
)
```

### Using Convenience Constructors

```dart
// All sides equal
VPadding.all(
  30,
  startFrame: 0,
  fadeInFrames: 20,
  child: ContentWidget(),
)

// Horizontal and vertical
VPadding.symmetric(
  horizontal: 50,
  vertical: 100,
  startFrame: 15,
  fadeInFrames: 15,
  child: ContentWidget(),
)

// Individual sides
VPadding.only(
  left: 100,
  right: 100,
  bottom: 50,
  startFrame: 30,
  fadeInFrames: 20,
  child: ContentWidget(),
)
```

### Safe Area Style Padding

```dart
Scene(
  durationInFrames: 180,
  background: Background.solid(Colors.black),
  children: [
    VPadding(
      padding: EdgeInsets.symmetric(horizontal: 80, vertical: 120),
      startFrame: 0,
      fadeInFrames: 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Title', style: titleStyle),
          SizedBox(height: 20),
          Text('Description text that stays within safe margins.'),
        ],
      ),
    ),
  ],
)
```

### Nested Padding

```dart
VPadding(
  padding: EdgeInsets.all(40),
  startFrame: 0,
  fadeInFrames: 20,
  child: VPadding(
    padding: EdgeInsets.all(20),
    startFrame: 15,
    fadeInFrames: 20,
    child: Text('Double padded'),
  ),
)
```

### In a Layout

```dart
LayerStack(
  children: [
    Layer.background(
      child: Container(color: Colors.black),
    ),

    // Content with padding
    VPadding(
      padding: EdgeInsets.symmetric(horizontal: 60, vertical: 80),
      startFrame: 0,
      fadeInFrames: 25,
      child: VColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 20,
        children: [
          Text('Welcome', style: titleStyle),
          Text('This is your personalized story.'),
          Text('Let\'s see what you accomplished.'),
        ],
      ),
    ),
  ],
)
```

---

## Comparison with Padding

| Feature | Padding | VPadding |
|---------|---------|----------|
| Adds padding | Yes | Yes |
| EdgeInsets support | Yes | Yes |
| Convenience constructors | No | Yes (.all, .symmetric, .only) |
| Time-based visibility | No | Yes |
| Fade transitions | No | Yes |

---

## Related

- [VCenter](v-center.md) - Center with timing
- [VSizedBox](v-sized-box.md) - SizedBox with timing
- [VPositioned](v-positioned.md) - Positioned with timing
