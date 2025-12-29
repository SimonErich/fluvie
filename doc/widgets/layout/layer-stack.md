# LayerStack

> **Video composition stack with layer management**

`LayerStack` is a specialized Stack widget designed for video compositions. It provides automatic z-index sorting, support for timed layers, and convenient constructors for backgrounds and overlays.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Examples](#examples)
- [Z-Index Sorting](#z-index-sorting)
- [Related](#related)

---

## Overview

`LayerStack` works just like Flutter's `Stack`, but with video-specific enhancements:

```dart
LayerStack(
  children: [
    Layer.background(
      child: GradientBackground(),
    ),
    Layer(
      id: 'title',
      startFrame: 30,
      endFrame: 120,
      fadeInFrames: 15,
      fadeOutFrames: 15,
      child: TitleWidget(),
    ),
    Layer.overlay(
      child: Watermark(),
    ),
  ],
)
```

### Key Features

- **Mixed children** - Use `Layer` widgets or regular widgets together
- **Automatic z-index sorting** - Layers with `zIndex` are automatically sorted
- **Time-based visibility** - Layers can appear/disappear based on frame number
- **Background/overlay helpers** - Convenient constructors for common patterns

---

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `children` | `List<Widget>` | **required** | The layers in this stack |
| `alignment` | `AlignmentGeometry` | `topStart` | Alignment for non-positioned children |
| `fit` | `StackFit` | `loose` | How to size non-positioned children |
| `textDirection` | `TextDirection?` | `null` | Text direction for alignment |
| `clipBehavior` | `Clip` | `hardEdge` | Clip behavior for the stack |

---

## Examples

### Basic Layer Stack

```dart
LayerStack(
  children: [
    // Background layer (always behind)
    Layer.background(
      child: Container(color: Colors.blue),
    ),

    // Main content
    Layer(
      startFrame: 30,
      endFrame: 120,
      fadeInFrames: 15,
      child: Center(child: Text('Hello!')),
    ),

    // Overlay (always on top)
    Layer.overlay(
      child: Watermark(),
    ),
  ],
)
```

### With Regular Widgets

You can mix `Layer` widgets with regular Flutter widgets:

```dart
LayerStack(
  children: [
    // Regular widget - always visible
    Container(color: Colors.black),

    // Layer with timing
    Layer(
      startFrame: 30,
      fadeInFrames: 15,
      child: Text('Appears at frame 30'),
    ),

    // Another regular widget
    Positioned(
      bottom: 20,
      right: 20,
      child: Logo(),
    ),
  ],
)
```

### Multiple Timed Layers

```dart
LayerStack(
  children: [
    Layer.background(
      child: AnimatedGradient(),
    ),

    // First title: frames 0-60
    Layer(
      startFrame: 0,
      endFrame: 60,
      fadeInFrames: 15,
      fadeOutFrames: 15,
      child: Center(child: Text('Welcome')),
    ),

    // Second title: frames 45-120
    Layer(
      startFrame: 45,
      endFrame: 120,
      fadeInFrames: 15,
      fadeOutFrames: 15,
      child: Center(child: Text('To Fluvie')),
    ),

    // Particles throughout
    Layer.overlay(
      child: ParticleEffect.sparkles(),
    ),
  ],
)
```

### Timeline Visualization

```
Frame:    0    15   30   45   60   75   90   105  120
          |     |    |    |    |    |    |     |    |
Welcome:  ████████████████████████████
                         ↑fade out
To Fluvie:              ██████████████████████████████
                        ↑fade in
Particles: ████████████████████████████████████████████
```

---

## Z-Index Sorting

Layers with explicit `zIndex` values are automatically sorted:

```dart
LayerStack(
  children: [
    Layer(
      zIndex: 100,  // Will render on top
      child: TopContent(),
    ),
    Layer(
      zIndex: -100,  // Will render behind
      child: BackgroundContent(),
    ),
    Layer(
      // No zIndex - uses list order
      child: MiddleContent(),
    ),
  ],
)
```

### Z-Index Rules

1. Higher `zIndex` = rendered on top
2. `Layer.background()` has `zIndex: -1000` by default
3. `Layer.overlay()` has `zIndex: 1000` by default
4. Layers without `zIndex` use their position in the list
5. Equal `zIndex` values preserve original list order

---

## Comparison with Stack

| Feature | Stack | LayerStack |
|---------|-------|------------|
| Basic stacking | Yes | Yes |
| Z-index sorting | No | Yes |
| Layer timing | No | Yes (via Layer) |
| Fade transitions | No | Yes (via Layer) |
| Background/overlay helpers | No | Yes |

---

## Related

- [Layer](layer.md) - Individual layer widget
- [VStack](v-stack.md) - Video-aware Stack with timing
- [VPositioned](v-positioned.md) - Positioned widget with timing
