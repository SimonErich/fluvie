# VStack

> **Video-aware Stack with timing and fading**

`VStack` extends Flutter's `Stack` with video-specific properties like `startFrame`, `endFrame`, and fade transitions. It's perfect for creating timed stack compositions.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Examples](#examples)
- [Comparison with Stack](#comparison-with-stack)
- [Related](#related)

---

## Overview

`VStack` works exactly like Flutter's `Stack`, but can be shown/hidden based on frame numbers and includes automatic fade transitions:

```dart
VStack(
  startFrame: 30,
  endFrame: 120,
  fadeInFrames: 15,
  fadeOutFrames: 15,
  alignment: Alignment.center,
  children: [
    Background(),
    Content(),
  ],
)
```

### When to Use

Use `VStack` when you need:
- A Stack that appears/disappears at specific frames
- A Stack with fade in/out transitions
- To group multiple positioned children with shared timing

---

## Properties

### Stack Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `children` | `List<Widget>` | `[]` | Widgets to stack |
| `alignment` | `AlignmentGeometry` | `topStart` | Alignment for non-positioned children |
| `fit` | `StackFit` | `loose` | How to size non-positioned children |
| `textDirection` | `TextDirection?` | `null` | Text direction for alignment |
| `clipBehavior` | `Clip` | `hardEdge` | Clip behavior |

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

### Basic Timed Stack

```dart
VStack(
  startFrame: 30,
  endFrame: 120,
  fadeInFrames: 15,
  alignment: Alignment.center,
  children: [
    Container(color: Colors.blue),
    Text('Centered Text'),
  ],
)
```

### Positioned Children

```dart
VStack(
  startFrame: 0,
  endFrame: 180,
  fadeInFrames: 20,
  fadeOutFrames: 20,
  children: [
    // Background
    Positioned.fill(
      child: Image.asset('assets/bg.jpg', fit: BoxFit.cover),
    ),

    // Title at top
    Positioned(
      top: 50,
      left: 0,
      right: 0,
      child: Text('Title', textAlign: TextAlign.center),
    ),

    // Content in center
    Positioned(
      top: 200,
      left: 50,
      right: 50,
      child: ContentWidget(),
    ),

    // Footer at bottom
    Positioned(
      bottom: 50,
      left: 0,
      right: 0,
      child: Text('Footer', textAlign: TextAlign.center),
    ),
  ],
)
```

### Nested VStacks with Different Timing

```dart
LayerStack(
  children: [
    // First section: frames 0-90
    VStack(
      startFrame: 0,
      endFrame: 90,
      fadeInFrames: 15,
      fadeOutFrames: 15,
      children: [
        Positioned.fill(child: BlueBackground()),
        Center(child: Text('Section 1')),
      ],
    ),

    // Second section: frames 60-150
    VStack(
      startFrame: 60,
      endFrame: 150,
      fadeInFrames: 15,
      fadeOutFrames: 15,
      children: [
        Positioned.fill(child: GreenBackground()),
        Center(child: Text('Section 2')),
      ],
    ),
  ],
)
```

### With Fade Curves

```dart
VStack(
  startFrame: 30,
  endFrame: 120,
  fadeInFrames: 25,
  fadeOutFrames: 25,
  fadeInCurve: Curves.easeOutCubic,
  fadeOutCurve: Curves.easeInQuart,
  children: [
    Background(),
    Content(),
  ],
)
```

---

## Comparison with Stack

| Feature | Stack | VStack |
|---------|-------|--------|
| Stack children | Yes | Yes |
| Alignment | Yes | Yes |
| Positioned children | Yes | Yes |
| Time-based visibility | No | Yes |
| Fade transitions | No | Yes |
| Video-aware | No | Yes |

### When to Use Each

```dart
// Use Stack for always-visible content
Stack(
  children: [
    Background(),
    Content(),
  ],
)

// Use VStack when you need timing
VStack(
  startFrame: 30,
  fadeInFrames: 15,
  children: [
    Background(),
    Content(),
  ],
)
```

---

## Related

- [LayerStack](layer-stack.md) - Layer-based composition
- [VPositioned](v-positioned.md) - Positioned with timing
- [VColumn](v-column.md) - Column with timing
- [VRow](v-row.md) - Row with timing
