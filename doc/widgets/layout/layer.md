# Layer

> **Time-controlled layer with fading and blend modes**

`Layer` is a single layer within a `LayerStack` that provides time-based visibility, opacity transitions, blend modes, and transforms. It's the primary widget for controlling when and how content appears in your video.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Constructors](#constructors)
- [Examples](#examples)
- [Fade Transitions](#fade-transitions)
- [Blend Modes](#blend-modes)
- [Related](#related)

---

## Overview

`Layer` wraps content with video-specific capabilities:

```dart
Layer(
  id: 'title',
  startFrame: 30,
  endFrame: 120,
  fadeInFrames: 15,
  fadeOutFrames: 15,
  child: Text('Hello!'),
)
```

### When to Use

Use `Layer` when you need:
- Time-based visibility (show/hide at specific frames)
- Fade in/out transitions
- Blend modes for compositing effects
- Z-index control within a LayerStack

---

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `child` | `Widget` | **required** | The widget content |
| `id` | `String?` | `null` | Identifier for debugging |
| `startFrame` | `int?` | `null` | Frame to become visible (null = from start) |
| `endFrame` | `int?` | `null` | Frame to become invisible (null = until end) |
| `fadeInFrames` | `int` | `0` | Duration of fade-in transition |
| `fadeOutFrames` | `int` | `0` | Duration of fade-out transition |
| `fadeInCurve` | `Curve` | `easeOut` | Easing for fade-in |
| `fadeOutCurve` | `Curve` | `easeIn` | Easing for fade-out |
| `opacity` | `double` | `1.0` | Base opacity (0.0-1.0) |
| `blendMode` | `BlendMode` | `srcOver` | Compositing blend mode |
| `enabled` | `bool` | `true` | Whether layer is rendered |
| `zIndex` | `int?` | `null` | Explicit z-ordering |
| `transform` | `Matrix4?` | `null` | Transform matrix |
| `transformAlignment` | `AlignmentGeometry` | `center` | Transform origin |

---

## Constructors

### Default Constructor

```dart
Layer(
  startFrame: 30,
  endFrame: 120,
  fadeInFrames: 15,
  child: Content(),
)
```

### Layer.background

Creates a layer that renders behind others (zIndex: -1000):

```dart
Layer.background(
  fadeInFrames: 30,
  child: GradientBackground(),
)
```

### Layer.overlay

Creates a layer that renders on top of others (zIndex: 1000):

```dart
Layer.overlay(
  blendMode: BlendMode.screen,
  child: LensFlare(),
)
```

---

## Examples

### Basic Timed Layer

```dart
LayerStack(
  children: [
    Layer.background(
      child: Container(color: Colors.black),
    ),
    Layer(
      startFrame: 30,    // Appear at frame 30
      endFrame: 120,     // Disappear at frame 120
      fadeInFrames: 15,  // Fade in over 15 frames
      fadeOutFrames: 15, // Fade out over 15 frames
      child: Center(
        child: Text(
          'Hello, World!',
          style: TextStyle(fontSize: 72, color: Colors.white),
        ),
      ),
    ),
  ],
)
```

### Layered Composition

```dart
LayerStack(
  children: [
    // Background
    Layer.background(
      child: Image.asset('assets/bg.jpg', fit: BoxFit.cover),
    ),

    // Gradient overlay for text readability
    Layer(
      opacity: 0.7,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black],
          ),
        ),
      ),
    ),

    // Main content with timing
    Layer(
      startFrame: 30,
      endFrame: 180,
      fadeInFrames: 20,
      fadeOutFrames: 30,
      child: Positioned(
        bottom: 100,
        left: 50,
        right: 50,
        child: Text('Your Story'),
      ),
    ),

    // Sparkle overlay
    Layer.overlay(
      fadeInFrames: 60,
      child: ParticleEffect.sparkles(),
    ),
  ],
)
```

### With Transform

```dart
Layer(
  startFrame: 0,
  fadeInFrames: 30,
  transform: Matrix4.identity()
    ..scale(1.1)
    ..rotateZ(0.05),
  transformAlignment: Alignment.center,
  child: Image.asset('assets/photo.jpg'),
)
```

### Conditional Rendering

```dart
Layer(
  enabled: showWatermark,  // Dynamically enable/disable
  child: Positioned(
    bottom: 20,
    right: 20,
    child: Watermark(),
  ),
)
```

---

## Fade Transitions

### How Fading Works

```
Frame:    0    15   30   45   60   75   90   105  120
          |     |    |    |    |    |    |     |    |
Opacity:  0%   →→→  100% ─────────────────────  →→→  0%
          ↑ fade in                              ↑ fade out
          startFrame                             endFrame
```

### Custom Curves

```dart
Layer(
  startFrame: 30,
  endFrame: 120,
  fadeInFrames: 20,
  fadeOutFrames: 20,
  fadeInCurve: Curves.easeOutCubic,   // Smooth fade in
  fadeOutCurve: Curves.easeInExpo,    // Quick fade out
  child: Content(),
)
```

### Partial Opacity

```dart
Layer(
  opacity: 0.8,  // Max opacity is 80%
  fadeInFrames: 15,  // Fades from 0% to 80%
  child: Overlay(),
)
```

---

## Blend Modes

Layer supports Flutter's blend modes for special compositing effects:

```dart
// Screen blend for light effects
Layer.overlay(
  blendMode: BlendMode.screen,
  child: LightFlare(),
)

// Multiply for shadows
Layer(
  blendMode: BlendMode.multiply,
  child: ShadowOverlay(),
)

// Color dodge for glow effects
Layer(
  blendMode: BlendMode.colorDodge,
  child: GlowEffect(),
)
```

### Common Blend Modes

| Mode | Effect | Use Case |
|------|--------|----------|
| `srcOver` | Normal (default) | Standard layering |
| `screen` | Lightens | Light effects, lens flares |
| `multiply` | Darkens | Shadows, vignettes |
| `overlay` | Contrast | Color grading |
| `colorDodge` | Bright highlights | Glow effects |

**Note:** Non-standard blend modes use `saveLayer` which may cause transparency artifacts. For best results, ensure blended content has opaque backgrounds.

---

## Visibility Rules

| Condition | Visible |
|-----------|---------|
| `enabled: false` | Never |
| `frame < startFrame` | No |
| `frame >= endFrame` | No |
| `startFrame <= frame < endFrame` | Yes |
| `startFrame: null` | Visible from frame 0 |
| `endFrame: null` | Visible until composition ends |

---

## Related

- [LayerStack](layer-stack.md) - Container for layers
- [VPositioned](v-positioned.md) - Positioned with timing
- [Fade](../core/fade.md) - Low-level fade widget
- [TimeConsumer](../core/time-consumer.md) - Frame-based animation
