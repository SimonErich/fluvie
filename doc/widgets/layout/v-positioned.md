# VPositioned

> **Video-aware Positioned with timing, fading, and hero transitions**

`VPositioned` extends Flutter's `Positioned` with video-specific properties including `startFrame`, `endFrame`, fade transitions, and hero-style cross-scene animations.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Constructors](#constructors)
- [Examples](#examples)
- [Hero Transitions](#hero-transitions)
- [Related](#related)

---

## Overview

`VPositioned` positions content within a `Stack` or `VStack` while adding video timing capabilities:

```dart
VStack(
  children: [
    VPositioned(
      left: 100,
      top: 200,
      startFrame: 30,
      fadeInFrames: 15,
      child: Text('Positioned Content'),
    ),
  ],
)
```

### When to Use

Use `VPositioned` when you need:
- Positioned content that appears/disappears at specific frames
- Positioned content with fade in/out transitions
- Hero-style animations between scenes
- Absolute positioning with video timing

---

## Properties

### Positioned Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `child` | `Widget` | **required** | Widget to position |
| `left` | `double?` | `null` | Distance from left edge |
| `top` | `double?` | `null` | Distance from top edge |
| `right` | `double?` | `null` | Distance from right edge |
| `bottom` | `double?` | `null` | Distance from bottom edge |
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

### Hero Property

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `heroKey` | `GlobalKey?` | `null` | Key for cross-scene hero animations |

---

## Constructors

### Default Constructor

```dart
VPositioned(
  left: 100,
  top: 200,
  child: Content(),
)
```

### VPositioned.fill

Fill the entire Stack:

```dart
VPositioned.fill(
  startFrame: 0,
  fadeInFrames: 30,
  child: BackgroundContent(),
)
```

### VPositioned.fromOffset

Create from an `Offset`:

```dart
VPositioned.fromOffset(
  offset: Offset(100, 200),
  width: 300,
  height: 200,
  child: Content(),
)
```

### VPositioned.fromRect

Create from a `Rect`:

```dart
VPositioned.fromRect(
  rect: Rect.fromLTWH(100, 200, 300, 200),
  child: Content(),
)
```

---

## Examples

### Basic Positioning

```dart
VStack(
  children: [
    VPositioned(
      left: 50,
      top: 100,
      child: Text('Top Left Area'),
    ),
    VPositioned(
      right: 50,
      bottom: 100,
      child: Text('Bottom Right Area'),
    ),
  ],
)
```

### With Timing

```dart
VStack(
  children: [
    // Title appears at frame 30
    VPositioned(
      left: 0,
      right: 0,
      top: 100,
      startFrame: 30,
      fadeInFrames: 20,
      child: Text(
        'Welcome',
        textAlign: TextAlign.center,
        style: titleStyle,
      ),
    ),

    // Subtitle appears at frame 50
    VPositioned(
      left: 0,
      right: 0,
      top: 200,
      startFrame: 50,
      fadeInFrames: 20,
      child: Text(
        'to your story',
        textAlign: TextAlign.center,
        style: subtitleStyle,
      ),
    ),
  ],
)
```

### Fill Background

```dart
VStack(
  children: [
    VPositioned.fill(
      startFrame: 0,
      fadeInFrames: 30,
      child: Image.asset('assets/bg.jpg', fit: BoxFit.cover),
    ),
    VPositioned(
      left: 50,
      right: 50,
      bottom: 100,
      startFrame: 30,
      fadeInFrames: 20,
      child: Text('Overlay Text'),
    ),
  ],
)
```

### Gradient Overlay

```dart
VStack(
  children: [
    // Image background
    VPositioned.fill(
      child: Image.asset('assets/photo.jpg', fit: BoxFit.cover),
    ),

    // Gradient for text readability
    VPositioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: 300,
      startFrame: 0,
      fadeInFrames: 20,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
      ),
    ),

    // Text at bottom
    VPositioned(
      left: 50,
      right: 50,
      bottom: 50,
      startFrame: 30,
      fadeInFrames: 20,
      child: Text('Photo Caption', style: captionStyle),
    ),
  ],
)
```

### Corner Positioned Elements

```dart
VStack(
  children: [
    // Top left
    VPositioned(
      left: 20,
      top: 20,
      startFrame: 0,
      fadeInFrames: 15,
      child: Logo(),
    ),

    // Top right
    VPositioned(
      right: 20,
      top: 20,
      startFrame: 10,
      fadeInFrames: 15,
      child: DateWidget(),
    ),

    // Bottom left
    VPositioned(
      left: 20,
      bottom: 20,
      startFrame: 20,
      fadeInFrames: 15,
      child: Watermark(),
    ),

    // Bottom right
    VPositioned(
      right: 20,
      bottom: 20,
      startFrame: 30,
      fadeInFrames: 15,
      child: SocialHandle(),
    ),
  ],
)
```

---

## Hero Transitions

`VPositioned` supports hero-style transitions between scenes. When two `VPositioned` widgets in adjacent scenes share the same `heroKey`, the `Video` widget automatically animates between their positions during scene transitions.

### Basic Hero Animation

```dart
final photoKey = GlobalKey();

Video(
  fps: 30,
  width: 1920,
  height: 1080,
  defaultTransition: SceneTransition.crossFade(durationInFrames: 30),
  scenes: [
    // Scene 1: Photo in center
    Scene(
      durationInFrames: 90,
      children: [
        VPositioned(
          left: 710,  // Centered
          top: 340,
          width: 500,
          height: 400,
          heroKey: photoKey,
          child: Image.asset('assets/photo.jpg'),
        ),
      ],
    ),

    // Scene 2: Photo moves to corner
    Scene(
      durationInFrames: 90,
      children: [
        VPositioned(
          left: 50,   // Top left corner
          top: 50,
          width: 200,
          height: 160,
          heroKey: photoKey,  // Same key = animates position
          child: Image.asset('assets/photo.jpg'),
        ),
        VPositioned(
          left: 300,
          top: 50,
          child: Text('Your favorite photo'),
        ),
      ],
    ),
  ],
)
```

### Hero Animation Properties

The hero animation automatically interpolates:
- Position (`left`, `top`, `right`, `bottom`)
- Size (`width`, `height`)
- Transform (if specified)

### Requirements for Hero Transitions

1. Both `VPositioned` widgets must have the same `heroKey`
2. A scene transition must be set on the `Video` widget
3. The widgets should be in adjacent scenes

---

## Complete Example

```dart
Scene(
  durationInFrames: 180,
  background: Background.solid(Colors.black),
  children: [
    // Background image
    VPositioned.fill(
      fadeInFrames: 30,
      child: Opacity(
        opacity: 0.3,
        child: Image.asset('assets/bg.jpg', fit: BoxFit.cover),
      ),
    ),

    // Main title
    VPositioned(
      left: 0,
      right: 0,
      top: 200,
      startFrame: 30,
      fadeInFrames: 25,
      child: Text(
        '2024',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 120,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ),

    // Subtitle
    VPositioned(
      left: 0,
      right: 0,
      top: 350,
      startFrame: 50,
      fadeInFrames: 25,
      child: Text(
        'YOUR YEAR IN REVIEW',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 36,
          color: Colors.white70,
          letterSpacing: 8,
        ),
      ),
    ),

    // Stats at bottom
    VPositioned(
      left: 50,
      right: 50,
      bottom: 150,
      startFrame: 75,
      fadeInFrames: 25,
      child: VRow(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        stagger: StaggerConfig.slideUp(delay: 10),
        children: [
          StatWidget(value: '2,451', label: 'Minutes'),
          StatWidget(value: '128', label: 'Songs'),
          StatWidget(value: '32', label: 'Artists'),
        ],
      ),
    ),
  ],
)
```

---

## Related

- [VStack](v-stack.md) - Stack with timing
- [LayerStack](layer-stack.md) - Layer-based composition
- [Layer](layer.md) - Layer with timing
- [VCenter](v-center.md) - Center with timing
