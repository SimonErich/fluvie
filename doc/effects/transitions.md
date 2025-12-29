# Scene Transitions

> **Smooth transitions between scenes**

`SceneTransition` defines how one scene transitions to another, including transition type, duration, and easing curve. Transitions create professional-looking video flow.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Transition Types](#transition-types)
- [Examples](#examples)
- [Timing](#timing)
- [Related](#related)

---

## Overview

Apply transitions to scenes:

```dart
Scene(
  durationInFrames: 180,
  transitionIn: SceneTransition.crossFade(durationInFrames: 20),
  transitionOut: SceneTransition.slideLeft(durationInFrames: 15),
  children: [...],
)
```

### Transition Direction

- `transitionIn` - How this scene appears (from previous scene)
- `transitionOut` - How this scene disappears (to next scene)

---

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `type` | `SceneTransitionType` | - | Transition type |
| `durationInFrames` | `int` | varies | Transition duration |
| `curve` | `Curve` | `easeInOut` | Easing curve |

Additional properties for specific transitions:

| Property | Transitions | Description |
|----------|-------------|-------------|
| `wipeDirection` | `wipe` | Wipe direction |
| `maxZoom` | `zoomWarp` | Maximum zoom level |
| `zoomTarget` | `zoomWarp` | Zoom focus point |
| `bleedColor` | `colorBleed` | Color to transition through |

---

## Transition Types

### None (Instant Cut)

No transition, immediate switch:

```dart
SceneTransition.none()
```

Use for:
- Hard cuts
- Quick tempo edits
- Intentional abrupt changes

### Cross Fade

Smooth dissolve between scenes:

```dart
SceneTransition.crossFade(
  durationInFrames: 15,  // Default: 15
  curve: Curves.easeInOut,
)
```

Use for:
- Smooth scene changes
- Time passing
- Dream sequences

### Slide Transitions

New scene slides in from a direction:

```dart
// From right (push left)
SceneTransition.slideLeft(durationInFrames: 20)

// From left (push right)
SceneTransition.slideRight(durationInFrames: 20)

// From bottom (push up)
SceneTransition.slideUp(durationInFrames: 20)

// From top (push down)
SceneTransition.slideDown(durationInFrames: 20)
```

Use for:
- Page-like transitions
- Carousel effects
- Directional flow

### Scale

New scene scales in from center:

```dart
SceneTransition.scale(
  durationInFrames: 20,
  curve: Curves.easeInOut,
)
```

Use for:
- Focus/zoom transitions
- Revealing new content
- Attention-grabbing changes

### Wipe

Reveal new scene with a wipe:

```dart
SceneTransition.wipe(
  durationInFrames: 20,
  curve: Curves.easeInOut,
  wipeDirection: WipeDirection.leftToRight,
)
```

**Wipe Directions:**
- `WipeDirection.leftToRight`
- `WipeDirection.rightToLeft`
- `WipeDirection.topToBottom`
- `WipeDirection.bottomToTop`

Use for:
- Reveal transitions
- Presentation style
- Clean directional changes

### Zoom Warp

Cinematic zoom through space:

```dart
SceneTransition.zoomWarp(
  durationInFrames: 30,      // Default: 30
  curve: Curves.easeInOutCubic,
  maxZoom: 3.0,              // Default: 3.0
  zoomTarget: Alignment.center,  // Optional focus point
)
```

The outgoing scene zooms in dramatically while the incoming scene zooms out from the center, creating a warp-like effect.

Use for:
- Dramatic transitions
- Time/space jumps
- Cinematic emphasis

### Color Bleed

Color flows between scenes:

```dart
SceneTransition.colorBleed(
  durationInFrames: 25,      // Default: 25
  curve: Curves.easeInOut,
  bleedColor: Colors.white,  // Optional specific color
)
```

The dominant color "bleeds" from one scene to the next, creating cohesive color flow.

Use for:
- Artistic transitions
- Thematic connections
- Smooth color-based flow

---

## Examples

### Basic Cross Fade

```dart
Video(
  fps: 30,
  width: 1920,
  height: 1080,
  scenes: [
    Scene(
      durationInFrames: 150,
      transitionOut: SceneTransition.crossFade(durationInFrames: 20),
      children: [IntroContent()],
    ),
    Scene(
      durationInFrames: 180,
      transitionIn: SceneTransition.crossFade(durationInFrames: 20),
      children: [MainContent()],
    ),
  ],
)
```

### Slide Presentation

```dart
Video(
  fps: 30,
  scenes: [
    Scene(
      durationInFrames: 120,
      transitionOut: SceneTransition.slideLeft(durationInFrames: 15),
      children: [Slide1()],
    ),
    Scene(
      durationInFrames: 120,
      transitionIn: SceneTransition.slideLeft(durationInFrames: 15),
      transitionOut: SceneTransition.slideLeft(durationInFrames: 15),
      children: [Slide2()],
    ),
    Scene(
      durationInFrames: 120,
      transitionIn: SceneTransition.slideLeft(durationInFrames: 15),
      children: [Slide3()],
    ),
  ],
)
```

### Dramatic Reveal

```dart
Scene(
  durationInFrames: 180,
  transitionIn: SceneTransition.zoomWarp(
    durationInFrames: 40,
    maxZoom: 4.0,
  ),
  children: [
    VCenter(
      child: Text(
        'THE REVEAL',
        style: TextStyle(fontSize: 72, fontWeight: FontWeight.bold),
      ),
    ),
  ],
)
```

### Wipe Transition

```dart
Scene(
  durationInFrames: 150,
  transitionIn: SceneTransition.wipe(
    durationInFrames: 25,
    wipeDirection: WipeDirection.leftToRight,
    curve: Curves.easeInOut,
  ),
  children: [NewContent()],
)
```

### Mixed Transitions

```dart
Video(
  fps: 30,
  scenes: [
    // Scene 1: Fade out
    Scene(
      durationInFrames: 120,
      transitionOut: SceneTransition.crossFade(durationInFrames: 15),
      children: [Scene1Content()],
    ),

    // Scene 2: Fade in, slide out
    Scene(
      durationInFrames: 150,
      transitionIn: SceneTransition.crossFade(durationInFrames: 15),
      transitionOut: SceneTransition.slideUp(durationInFrames: 20),
      children: [Scene2Content()],
    ),

    // Scene 3: Slide in, zoom warp out
    Scene(
      durationInFrames: 180,
      transitionIn: SceneTransition.slideUp(durationInFrames: 20),
      transitionOut: SceneTransition.zoomWarp(durationInFrames: 30),
      children: [Scene3Content()],
    ),

    // Scene 4: Zoom warp in
    Scene(
      durationInFrames: 120,
      transitionIn: SceneTransition.zoomWarp(durationInFrames: 30),
      children: [FinalContent()],
    ),
  ],
)
```

### Color Theme Transition

```dart
Scene(
  durationInFrames: 150,
  background: Background.solid(Color(0xFF1a1a2e)),
  transitionOut: SceneTransition.colorBleed(
    durationInFrames: 25,
    bleedColor: Color(0xFF1a1a2e),  // Match scene color
  ),
  children: [...],
)
```

### Slow Dramatic Fade

```dart
Scene(
  durationInFrames: 240,
  transitionIn: SceneTransition.crossFade(
    durationInFrames: 60,  // 2 seconds at 30fps
    curve: Curves.easeInOut,
  ),
  transitionOut: SceneTransition.crossFade(
    durationInFrames: 60,
  ),
  children: [DramaticContent()],
)
```

### Quick Cuts

```dart
Video(
  fps: 30,
  scenes: [
    Scene(
      durationInFrames: 30,  // 1 second
      transitionOut: SceneTransition.none(),
      children: [Image1()],
    ),
    Scene(
      durationInFrames: 30,
      transitionOut: SceneTransition.none(),
      children: [Image2()],
    ),
    Scene(
      durationInFrames: 30,
      transitionOut: SceneTransition.none(),
      children: [Image3()],
    ),
  ],
)
```

---

## Timing

### Transition Duration Guidelines

| Duration | Effect | Use Case |
|----------|--------|----------|
| 5-10 frames | Quick, snappy | Fast-paced content |
| 15-20 frames | Standard | Most transitions |
| 25-40 frames | Smooth, deliberate | Dramatic moments |
| 60+ frames | Slow, cinematic | Major scene changes |

### Overlap Consideration

Transitions overlap scenes. Consider this in timing:

```
Scene 1:    |████████████████████|
                              ↓ 20 frame transition
Scene 2:              |████████████████████|
                      ↑ Scene 2 starts during transition
```

### Using progressAt()

Check transition progress:

```dart
final transition = SceneTransition.crossFade(durationInFrames: 20);

// At frame 10 of the transition
transition.progressAt(10);  // Returns 0.5

// With curve applied
transition.curvedProgressAt(10);  // Returns curved 0.5
```

---

## Choosing Transitions

| Scenario | Recommended Transition |
|----------|----------------------|
| Sequential content | `slideLeft` / `slideRight` |
| Time passing | `crossFade` |
| Dramatic reveal | `zoomWarp` / `scale` |
| Clean professional | `wipe` |
| Artistic/thematic | `colorBleed` |
| Quick montage | `none` (cuts) |
| Emotional moment | Long `crossFade` |

---

## Related

- [Scene](../widgets/core/scene.md) - Scene widget
- [Video](../widgets/core/video.md) - Video composition
- [Easing](../animations/easing.md) - Animation curves
