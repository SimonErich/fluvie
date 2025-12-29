# FloatingElement

> **Oscillating float animation for dynamic elements**

`FloatingElement` creates a natural floating effect by combining vertical oscillation with optional rotation, perfect for clouds, decorative elements, or attention-grabbing content.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Constructors](#constructors)
- [Examples](#examples)
- [Related](#related)

---

## Overview

Create gently floating elements:

```dart
FloatingElement(
  position: Offset(100, 200),
  floatAmplitude: Offset(0, 10),
  floatFrequency: 0.5,
  child: Image.asset('cloud.png'),
)
```

The element oscillates using a sine wave for smooth, natural motion.

---

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `child` | `Widget` | **required** | Widget to float |
| `position` | `Offset` | `Offset.zero` | Base position |
| `floatAmplitude` | `Offset` | `Offset(0, 10)` | Movement range (x, y) |
| `floatFrequency` | `double` | `0.5` | Cycles per second |
| `floatPhase` | `double` | `0.0` | Phase offset (0.0 - 1.0) |
| `rotation` | `double` | `0.0` | Base rotation (radians) |
| `rotationAmplitude` | `double` | `0.0` | Rotation oscillation (radians) |
| `showShadow` | `bool` | `false` | Show drop shadow |
| `shadowBlur` | `double` | `10` | Shadow blur radius |
| `shadowOffset` | `Offset` | `Offset(0, 5)` | Shadow position |
| `shadowColor` | `Color` | black 25% | Shadow color |

---

## Constructors

### Default Constructor

Full control:

```dart
FloatingElement(
  child: MyWidget(),
  position: Offset(100, 200),
  floatAmplitude: Offset(5, 12),
  floatFrequency: 0.4,
  floatPhase: 0.0,
)
```

### FloatingElement.withRotation

Adds gentle rotation oscillation:

```dart
FloatingElement.withRotation(
  child: Image.asset('leaf.png'),
  position: Offset(100, 200),
  floatAmplitude: Offset(0, 8),
  floatFrequency: 0.4,
  rotationDegrees: 3.0,  // Oscillate ±3 degrees
)
```

---

## Examples

### Basic Float

```dart
FloatingElement(
  position: Offset(100, 200),
  floatAmplitude: Offset(0, 15),
  floatFrequency: 0.5,
  child: Image.asset('assets/cloud.png'),
)
```

### Horizontal Float

```dart
FloatingElement(
  position: Offset(400, 300),
  floatAmplitude: Offset(20, 0),  // X movement only
  floatFrequency: 0.3,
  child: Icon(Icons.arrow_forward, size: 48),
)
```

### Combined Movement

```dart
FloatingElement(
  position: Offset(200, 200),
  floatAmplitude: Offset(10, 15),  // Both X and Y
  floatFrequency: 0.4,
  child: Icon(Icons.star, size: 48, color: Colors.yellow),
)
```

### With Rotation

```dart
FloatingElement.withRotation(
  position: Offset(300, 250),
  floatAmplitude: Offset(5, 10),
  floatFrequency: 0.35,
  rotationDegrees: 5.0,
  child: Image.asset('assets/balloon.png', width: 80),
)
```

### Multiple Floating Elements

Create depth with different phases:

```dart
Scene(
  durationInFrames: 300,
  background: Background.solid(Color(0xFF87CEEB)),
  children: [
    // Background clouds (slow, small)
    FloatingElement(
      position: Offset(100, 80),
      floatAmplitude: Offset(3, 8),
      floatFrequency: 0.25,
      floatPhase: 0.0,
      child: Opacity(
        opacity: 0.5,
        child: Image.asset('assets/cloud.png', width: 150),
      ),
    ),

    // Mid clouds
    FloatingElement(
      position: Offset(400, 120),
      floatAmplitude: Offset(5, 10),
      floatFrequency: 0.35,
      floatPhase: 0.3,
      child: Opacity(
        opacity: 0.7,
        child: Image.asset('assets/cloud.png', width: 180),
      ),
    ),

    // Foreground clouds (faster, larger movement)
    FloatingElement(
      position: Offset(600, 60),
      floatAmplitude: Offset(8, 12),
      floatFrequency: 0.45,
      floatPhase: 0.6,
      child: Image.asset('assets/cloud.png', width: 200),
    ),
  ],
)
```

### Floating Stars

```dart
Scene(
  durationInFrames: 240,
  background: Background.solid(Color(0xFF1a1a2e)),
  children: [
    // Main content
    VCenter(child: MainContent()),

    // Floating stars at different positions and phases
    for (int i = 0; i < 10; i++)
      FloatingElement(
        position: Offset(
          100.0 + (i * 150) % 800,
          80.0 + (i * 70) % 400,
        ),
        floatAmplitude: Offset(3 + (i % 4), 8 + (i % 5)),
        floatFrequency: 0.3 + (i % 3) * 0.1,
        floatPhase: i * 0.1,
        child: Icon(
          Icons.star,
          size: 16.0 + (i % 3) * 8,
          color: Colors.yellow.withOpacity(0.6 + (i % 4) * 0.1),
        ),
      ),
  ],
)
```

### With Shadow

```dart
FloatingElement(
  position: Offset(300, 200),
  floatAmplitude: Offset(0, 12),
  floatFrequency: 0.5,
  showShadow: true,
  shadowBlur: 15,
  shadowOffset: Offset(0, 8),
  shadowColor: Colors.black.withOpacity(0.3),
  child: Container(
    width: 100,
    height: 100,
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
    ),
    child: Icon(Icons.emoji_emotions, size: 50),
  ),
)
```

### Floating Cards

```dart
Scene(
  durationInFrames: 180,
  children: [
    FloatingElement(
      position: Offset(100, 200),
      floatAmplitude: Offset(5, 10),
      floatFrequency: 0.4,
      floatPhase: 0.0,
      showShadow: true,
      child: PhotoCard.simple(
        assetPath: 'assets/photo1.jpg',
        width: 200,
        height: 150,
      ),
    ),
    FloatingElement(
      position: Offset(350, 180),
      floatAmplitude: Offset(6, 12),
      floatFrequency: 0.35,
      floatPhase: 0.33,
      showShadow: true,
      child: PhotoCard.simple(
        assetPath: 'assets/photo2.jpg',
        width: 200,
        height: 150,
      ),
    ),
    FloatingElement(
      position: Offset(600, 220),
      floatAmplitude: Offset(4, 8),
      floatFrequency: 0.45,
      floatPhase: 0.66,
      showShadow: true,
      child: PhotoCard.simple(
        assetPath: 'assets/photo3.jpg',
        width: 200,
        height: 150,
      ),
    ),
  ],
)
```

### Floating with Rotation

```dart
FloatingElement.withRotation(
  position: Offset(400, 300),
  floatAmplitude: Offset(8, 15),
  floatFrequency: 0.3,
  rotationDegrees: 5.0,
  showShadow: true,
  child: Transform.rotate(
    angle: -0.1,  // Base tilt
    child: PolaroidFrame(
      size: Size(200, 230),
      caption: 'Memories',
      child: Image.asset('assets/memory.jpg', fit: BoxFit.cover),
    ),
  ),
)
```

---

## How It Works

The float animation uses a sine wave for smooth, natural motion:

```
Frame:    0       30       60       90      120
          |        |        |        |        |
Position:  ─      ╱╲       ─       ╱╲       ─
            ╲    ╱  ╲     ╱ ╲     ╱  ╲     ╱
             ╲──╱    ╲───╱   ╲───╱    ╲───╱
```

The `floatPhase` offsets when each element is in its cycle, preventing synchronized movement.

---

## Performance

FloatingElement uses `TimeConsumer` which recalculates position each frame. For many floating elements:

- Keep `floatAmplitude` values small
- Use lower `floatFrequency` for background elements
- Consider using CSS transforms for large counts (not available in Fluvie)

---

## Related

- [PropAnimation.float()](../animations/prop-animation.md) - Float as PropAnimation
- [PropAnimation.pulse()](../animations/prop-animation.md) - Pulsing scale
- [TimeConsumer](../widgets/core/time-consumer.md) - Frame-based animation
