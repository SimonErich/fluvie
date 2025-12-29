# Scene

> **Time-bounded section of a video**

`Scene` represents a distinct section of your video with its own duration, background, and content. Scenes are the primary building blocks within a `Video` widget.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Examples](#examples)
- [Timing](#timing)
- [Backgrounds](#backgrounds)
- [Transitions](#transitions)
- [SceneContext](#scenecontext)
- [Related](#related)

---

## Overview

A `Scene` defines:
- **Length** - How many frames the scene lasts
- **Background** - Solid color, gradient, or custom background
- **Content** - Child widgets displayed during the scene
- **Fading** - Fade in/out at scene boundaries
- **Transitions** - Effects when entering/leaving the scene

```dart
Scene(
  durationInFrames: 90, // 3 seconds at 30fps
  background: Background.solid(Colors.blue),
  fadeInFrames: 15,
  fadeOutFrames: 15,
  children: [
    VCenter(child: Text('Hello!')),
  ],
)
```

---

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `durationInFrames` | `int` | **required** | Scene duration in frames |
| `background` | `Background?` | `null` | Scene background |
| `children` | `List<Widget>` | `[]` | Content widgets |
| `fadeInFrames` | `int` | `0` | Frames to fade in |
| `fadeOutFrames` | `int` | `0` | Frames to fade out |
| `fadeInCurve` | `Curve` | `Curves.easeOut` | Fade in easing |
| `fadeOutCurve` | `Curve` | `Curves.easeIn` | Fade out easing |
| `transitionIn` | `SceneTransition?` | `null` | Override entrance transition |
| `transitionOut` | `SceneTransition?` | `null` | Override exit transition |

---

## Examples

### Basic Scene

```dart
Scene(
  durationInFrames: 90,
  background: Background.solid(Colors.indigo),
  children: [
    VCenter(
      child: Text(
        'Welcome',
        style: TextStyle(fontSize: 72, color: Colors.white),
      ),
    ),
  ],
)
```

### Scene with Fade

```dart
Scene(
  durationInFrames: 120,
  background: Background.solid(Colors.black),
  fadeInFrames: 20,   // Fade in over 20 frames
  fadeOutFrames: 30,  // Fade out over 30 frames
  fadeInCurve: Curves.easeOutCubic,
  fadeOutCurve: Curves.easeInCubic,
  children: [
    VCenter(child: Text('Smooth transitions')),
  ],
)
```

### Scene with Animated Gradient

```dart
Scene(
  durationInFrames: 150,
  background: Background.gradient(
    colors: {
      0: Color(0xFF6366F1),    // Start color
      75: Color(0xFF8B5CF6),   // Middle color
      150: Color(0xFFEC4899),  // End color
    },
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  children: [
    VCenter(child: Text('Color journey')),
  ],
)
```

### Multiple Layered Content

```dart
Scene(
  durationInFrames: 180,
  background: Background.solid(Colors.black),
  children: [
    // Background layer - full screen image
    Positioned.fill(
      child: Image.asset('assets/background.jpg', fit: BoxFit.cover),
    ),

    // Overlay gradient for text readability
    Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black87],
          ),
        ),
      ),
    ),

    // Text content
    VPositioned(
      bottom: 100,
      left: 50,
      right: 50,
      startFrame: 30,
      fadeInFrames: 20,
      child: Text('Layered composition'),
    ),

    // Particles on top
    Positioned.fill(
      child: ParticleEffect.sparkles(count: 30),
    ),
  ],
)
```

---

## Timing

### Scene Length

The `length` is measured in frames:

```dart
// At 30fps:
Scene(durationInFrames: 30)   // 1 second
Scene(durationInFrames: 90)   // 3 seconds
Scene(durationInFrames: 300)  // 10 seconds
Scene(durationInFrames: 1800) // 1 minute
```

### Child Timing

Children can have their own timing relative to the scene:

```dart
Scene(
  durationInFrames: 120,
  children: [
    // Visible for entire scene
    VCenter(child: Background()),

    // Appears at frame 30 within scene
    VPositioned(
      startFrame: 30,
      fadeInFrames: 15,
      child: Title(),
    ),

    // Appears at frame 60, disappears at frame 100
    VPositioned(
      startFrame: 60,
      endFrame: 100,
      fadeInFrames: 10,
      fadeOutFrames: 10,
      child: Subtitle(),
    ),
  ],
)
```

### Timeline Example

```
Scene: length=120, fadeIn=15, fadeOut=15
├── Frame 0-15: Scene fading in
├── Frame 15-105: Scene fully visible
└── Frame 105-120: Scene fading out

Children:
├── VPositioned(startFrame: 30)
│   └── Appears at scene frame 30 (global varies by scene position)
└── VPositioned(startFrame: 60, endFrame: 100)
    └── Visible from scene frame 60 to 100
```

---

## Backgrounds

### Solid Color

```dart
Scene(
  background: Background.solid(Colors.indigo),
  // ...
)
```

### Static Gradient

```dart
Scene(
  background: Background.staticGradient(
    colors: [Colors.purple, Colors.blue],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  ),
  // ...
)
```

### Animated Gradient

Colors animate over time based on frame number:

```dart
Scene(
  durationInFrames: 120,
  background: Background.gradient(
    colors: {
      0: Color(0xFF1a1a2e),    // Frame 0
      60: Color(0xFF16213e),   // Frame 60
      120: Color(0xFF0f3460),  // Frame 120
    },
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  // ...
)
```

### Custom Background

Use a child widget as background:

```dart
Scene(
  durationInFrames: 180,
  children: [
    // Custom background as first child
    Positioned.fill(
      child: CustomPainter(/* ... */),
    ),

    // Content on top
    VCenter(child: Content()),
  ],
)
```

---

## Transitions

### Default Transition

Set on the parent `Video`:

```dart
Video(
  defaultTransition: const SceneTransition.crossFade(durationInFrames: 20),
  scenes: [
    Scene(durationInFrames: 90, /* uses default */),
    Scene(durationInFrames: 60, /* uses default */),
  ],
)
```

### Per-Scene Transition

Override for specific scenes:

```dart
Scene(
  durationInFrames: 90,
  transitionIn: const SceneTransition.slideUp(durationInFrames: 25),
  transitionOut: const SceneTransition.crossFade(durationInFrames: 15),
  children: [/* ... */],
)
```

### Available Transitions

```dart
SceneTransition.crossFade(durationInFrames: 20)
SceneTransition.slideUp(durationInFrames: 20)
SceneTransition.slideDown(durationInFrames: 20)
SceneTransition.slideLeft(durationInFrames: 20)
SceneTransition.slideRight(durationInFrames: 20)
SceneTransition.zoomIn(durationInFrames: 20)
SceneTransition.zoomOut(durationInFrames: 20)
```

---

## SceneContext

Access scene timing information from child widgets:

```dart
Scene(
  durationInFrames: 120,
  children: [
    Builder(
      builder: (context) {
        final sceneContext = SceneContext.of(context);

        if (sceneContext != null) {
          print('Scene start frame: ${sceneContext.sceneStartFrame}');
          print('Scene durationInFrames: ${sceneContext.sceneDurationInFrames}');
          print('Scene progress: ${sceneContext.progress}');
        }

        return MyWidget();
      },
    ),
  ],
)
```

### SceneContext Properties

| Property | Type | Description |
|----------|------|-------------|
| `sceneStartFrame` | `int` | Global frame where scene starts |
| `sceneDurationInFrames` | `int` | Scene duration in frames |
| `progress` | `double` | 0.0-1.0 progress through scene |

### Using with TimeConsumer

```dart
TimeConsumer(
  builder: (context, globalFrame, globalProgress) {
    final sceneContext = SceneContext.of(context);

    // Get local frame within scene
    final localFrame = sceneContext != null
        ? globalFrame - sceneContext.sceneStartFrame
        : globalFrame;

    // Get scene-specific progress
    final sceneProgress = sceneContext?.progress ?? globalProgress;

    return AnimatedWidget(
      localFrame: localFrame,
      progress: sceneProgress,
    );
  },
)
```

---

## Best Practices

### 1. Keep Scenes Focused

Each scene should have a clear purpose:

```dart
// Good: Each scene has one focus
Scene(durationInFrames: 90, children: [IntroTitle()]),
Scene(durationInFrames: 120, children: [MainContent()]),
Scene(durationInFrames: 60, children: [CallToAction()]),

// Avoid: One giant scene with everything
Scene(durationInFrames: 500, children: [/* everything */]),
```

### 2. Use Consistent Timing

Pick a timing convention and stick to it:

```dart
// Define constants
const int oneSecond = 30;
const int halfSecond = 15;

Scene(
  durationInFrames: 4 * oneSecond,
  fadeInFrames: halfSecond,
  fadeOutFrames: halfSecond,
  // ...
)
```

### 3. Layer Content Properly

Order matters - later children render on top:

```dart
Scene(
  children: [
    // 1. Background (bottom)
    Positioned.fill(child: Background()),

    // 2. Main content
    VCenter(child: Content()),

    // 3. Effects on top
    Positioned.fill(child: ParticleEffect()),

    // 4. Overlays (top)
    Positioned.fill(child: Vignette()),
  ],
)
```

---

## Related

- [Video](video.md) - Parent container
- [VPositioned](../layout/v-positioned.md) - Positioned content with timing
- [Background](../../effects/backgrounds.md) - Background options
- [SceneTransition](../../effects/transitions.md) - Transition types
