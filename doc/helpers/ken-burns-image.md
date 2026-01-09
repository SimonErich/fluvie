# KenBurnsImage

> **Cinematic pan and zoom effect for still images**

`KenBurnsImage` applies the Ken Burns effect to images - a slow zoom and pan that creates cinematic movement on still photographs, commonly used in documentaries.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Constructors](#constructors)
- [Examples](#examples)
- [Related](#related)

---

## Overview

Create cinematic image movement:

```dart
// Using child parameter (recommended - supports any image source)
KenBurnsImage(
  child: Image.network('https://example.com/landscape.jpg', fit: BoxFit.cover),
  width: 800,
  height: 600,
  startScale: 1.0,
  endScale: 1.3,
  startAlignment: Alignment.centerLeft,
  endAlignment: Alignment.centerRight,
)

// Using assetPath (legacy - for local assets only)
KenBurnsImage(
  assetPath: 'assets/landscape.jpg',
  width: 800,
  height: 600,
  startScale: 1.0,
  endScale: 1.3,
  startAlignment: Alignment.centerLeft,
  endAlignment: Alignment.centerRight,
)
```

The image slowly zooms and pans over the scene duration.

---

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `child` | `Widget?` | `null` | Image widget (recommended) |
| `assetPath` | `String?` | `null` | Path to image asset (deprecated) |
| `width` | `double` | **required** | Container width |
| `height` | `double` | **required** | Container height |
| `startScale` | `double` | `1.0` | Initial zoom level |
| `endScale` | `double` | `1.2` | Final zoom level |
| `startAlignment` | `Alignment` | `center` | Initial focus point |
| `endAlignment` | `Alignment` | `center` | Final focus point |
| `fit` | `BoxFit` | `cover` | Image fit mode |
| `borderRadius` | `BorderRadius?` | `null` | Corner rounding |
| `curve` | `Curve` | `linear` | Animation curve |
| `errorBuilder` | `Function?` | `null` | Error widget builder |

> **Note:** Either `child` or `assetPath` must be provided, but not both.
> The `child` parameter is recommended as it supports any widget type including `Image.network`, `Image.asset`, SVGs, and custom widgets.

---

## Constructors

### Default Constructor

Full control over zoom and pan:

```dart
// Using child (recommended - any image source)
KenBurnsImage(
  child: Image.network('https://example.com/photo.jpg', fit: BoxFit.cover),
  width: 800,
  height: 600,
  startScale: 1.0,
  endScale: 1.3,
  startAlignment: Alignment.topLeft,
  endAlignment: Alignment.bottomRight,
  curve: Curves.easeInOut,
)

// Using assetPath (legacy - local assets only)
KenBurnsImage(
  assetPath: 'assets/photo.jpg',
  width: 800,
  height: 600,
  startScale: 1.0,
  endScale: 1.3,
  startAlignment: Alignment.topLeft,
  endAlignment: Alignment.bottomRight,
  curve: Curves.easeInOut,
)
```

### KenBurnsImage.zoomIn

Simple zoom towards a focus point:

```dart
KenBurnsImage.zoomIn(
  assetPath: 'assets/photo.jpg',
  width: 800,
  height: 600,
  zoomAmount: 0.2,           // Zoom 20%
  focus: Alignment.center,   // Zoom target
)
```

### KenBurnsImage.pan

Pan across the image without zooming:

```dart
KenBurnsImage.pan(
  assetPath: 'assets/panorama.jpg',
  width: 800,
  height: 400,
  from: Alignment.centerLeft,
  to: Alignment.centerRight,
  scale: 1.2,  // Slight zoom enables panning
)
```

### KenBurnsImage.zoomAndPan

Combined zoom and pan:

```dart
KenBurnsImage.zoomAndPan(
  assetPath: 'assets/landscape.jpg',
  width: 800,
  height: 600,
  startScale: 1.0,
  endScale: 1.3,
  from: Alignment.topLeft,
  to: Alignment.bottomRight,
)
```

---

## Examples

### Basic Zoom In

```dart
KenBurnsImage.zoomIn(
  assetPath: 'assets/portrait.jpg',
  width: 600,
  height: 800,
  zoomAmount: 0.15,
  focus: Alignment.center,
)
```

### Zoom to Face

```dart
// Zoom toward the upper portion (assuming face is there)
KenBurnsImage.zoomIn(
  assetPath: 'assets/person.jpg',
  width: 600,
  height: 800,
  zoomAmount: 0.25,
  focus: Alignment(0, -0.3),  // Slightly above center
)
```

### Horizontal Pan

```dart
KenBurnsImage.pan(
  assetPath: 'assets/cityscape.jpg',
  width: 1000,
  height: 400,
  from: Alignment.centerLeft,
  to: Alignment.centerRight,
  scale: 1.3,
)
```

### Vertical Pan

```dart
KenBurnsImage.pan(
  assetPath: 'assets/skyscraper.jpg',
  width: 600,
  height: 400,
  from: Alignment.bottomCenter,
  to: Alignment.topCenter,
  scale: 1.4,
)
```

### Diagonal Movement

```dart
KenBurnsImage.zoomAndPan(
  assetPath: 'assets/landscape.jpg',
  width: 800,
  height: 600,
  startScale: 1.0,
  endScale: 1.25,
  from: Alignment.topLeft,
  to: Alignment.bottomRight,
)
```

### With Rounded Corners

```dart
KenBurnsImage(
  assetPath: 'assets/photo.jpg',
  width: 600,
  height: 400,
  startScale: 1.0,
  endScale: 1.2,
  borderRadius: BorderRadius.circular(20),
)
```

### Photo Slideshow

```dart
Video(
  fps: 30,
  width: 1920,
  height: 1080,
  scenes: [
    Scene(
      durationInFrames: 150,
      transitionOut: SceneTransition.crossFade(durationInFrames: 20),
      children: [
        VPositioned.fill(
          child: KenBurnsImage.zoomIn(
            assetPath: 'assets/photo1.jpg',
            width: 1920,
            height: 1080,
            zoomAmount: 0.15,
          ),
        ),
      ],
    ),
    Scene(
      durationInFrames: 150,
      transitionOut: SceneTransition.crossFade(durationInFrames: 20),
      children: [
        VPositioned.fill(
          child: KenBurnsImage.pan(
            assetPath: 'assets/photo2.jpg',
            width: 1920,
            height: 1080,
            from: Alignment.centerLeft,
            to: Alignment.centerRight,
            scale: 1.2,
          ),
        ),
      ],
    ),
    Scene(
      durationInFrames: 150,
      children: [
        VPositioned.fill(
          child: KenBurnsImage.zoomAndPan(
            assetPath: 'assets/photo3.jpg',
            width: 1920,
            height: 1080,
            startScale: 1.0,
            endScale: 1.3,
            from: Alignment.bottomLeft,
            to: Alignment.topRight,
          ),
        ),
      ],
    ),
  ],
)
```

### With Overlay Text

```dart
Scene(
  durationInFrames: 180,
  children: [
    // Background with Ken Burns
    VPositioned.fill(
      child: KenBurnsImage.zoomIn(
        assetPath: 'assets/background.jpg',
        width: 1920,
        height: 1080,
        zoomAmount: 0.2,
      ),
    ),

    // Darkening overlay
    VPositioned.fill(
      child: Container(color: Colors.black.withOpacity(0.4)),
    ),

    // Text
    VCenter(
      startFrame: 30,
      fadeInFrames: 20,
      child: Text(
        'Your Journey',
        style: TextStyle(
          fontSize: 72,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ),
  ],
)
```

### Reverse Zoom (Zoom Out)

```dart
KenBurnsImage(
  assetPath: 'assets/detail.jpg',
  width: 800,
  height: 600,
  startScale: 1.3,   // Start zoomed in
  endScale: 1.0,     // End at normal size
  startAlignment: Alignment.center,
  endAlignment: Alignment.center,
)
```

### Slow Dramatic Zoom

```dart
Scene(
  durationInFrames: 300,  // 10 seconds at 30fps
  children: [
    VPositioned.fill(
      child: KenBurnsImage(
        assetPath: 'assets/dramatic.jpg',
        width: 1920,
        height: 1080,
        startScale: 1.0,
        endScale: 1.5,  // Large zoom
        startAlignment: Alignment.center,
        endAlignment: Alignment.center,
        curve: Curves.easeInOut,
      ),
    ),
  ],
)
```

---

## How It Works

The Ken Burns effect works by:
1. Displaying the image larger than the container
2. Clipping to the container bounds
3. Animating both scale and alignment over time

```
Container:    ┌──────────────────┐
              │                  │
              │   Visible Area   │  ← You see this
              │                  │
              └──────────────────┘

Actual Image: ┌─────────────────────────┐
              │                         │
              │    ┌──────────────┐    │
              │    │  Visible     │    │  ← Image is larger
              │    │              │    │
              │    └──────────────┘    │
              │                         │
              └─────────────────────────┘
```

The alignment determines which part of the larger image is visible.

---

## Tips

### Zoom Amount Guidelines

| Effect | Zoom Amount |
|--------|-------------|
| Subtle | 0.1 - 0.15 |
| Normal | 0.15 - 0.25 |
| Dramatic | 0.25 - 0.4 |

### Pan Requirements

Panning requires the image to be zoomed beyond 1.0 so there's room to pan:

```dart
// Won't pan - image fills container exactly
KenBurnsImage.pan(scale: 1.0, ...)  // No room to move

// Will pan - image is larger than container
KenBurnsImage.pan(scale: 1.2, ...)  // 20% extra for panning
```

---

## Related

- [PhotoCard](photo-card.md) - Photo card with Ken Burns option
- [EmbeddedVideo](../widgets/media/embedded-video.md) - Video clips
- [TimeConsumer](../widgets/core/time-consumer.md) - Frame-based animation
