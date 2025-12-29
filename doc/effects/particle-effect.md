# ParticleEffect

> **Animated particle systems for dynamic visual effects**

`ParticleEffect` creates deterministic particle systems with configurable count, size, speed, and direction. Particles are seeded for consistent rendering across video frames.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Presets](#presets)
- [Particle Types](#particle-types)
- [Directions](#directions)
- [Examples](#examples)
- [Related](#related)

---

## Overview

Add animated particles to your composition:

```dart
// Simple sparkles
ParticleEffect.sparkles(
  count: 25,
  color: Colors.yellow,
)

// Falling confetti
ParticleEffect.confetti(
  count: 40,
  colors: [Colors.red, Colors.blue, Colors.yellow, Colors.green],
)
```

### Deterministic Rendering

All particles are generated from a seed, ensuring identical results on every render:

```dart
ParticleEffect(
  count: 30,
  randomSeed: 42,  // Same seed = same particle positions/velocities
)
```

---

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `count` | `int` | `25` | Number of particles |
| `type` | `ParticleType` | `circle` | Shape of particles |
| `color` | `Color` | `white` | Primary particle color |
| `colors` | `List<Color>?` | `null` | Multiple colors for variety |
| `minSize` | `double` | `2` | Minimum particle size |
| `maxSize` | `double` | `6` | Maximum particle size |
| `minSpeed` | `double` | `1` | Minimum speed (pixels/frame) |
| `maxSpeed` | `double` | `3` | Maximum speed (pixels/frame) |
| `direction` | `ParticleDirection` | `down` | Movement direction |
| `randomSeed` | `int` | `42` | Seed for deterministic generation |
| `opacity` | `double` | `1.0` | Overall opacity |
| `fadeOut` | `bool` | `false` | Whether particles fade over time |

---

## Presets

### sparkles

Glittering star-shaped particles that move randomly and fade:

```dart
ParticleEffect.sparkles(
  count: 25,          // Number of sparkles
  color: Color(0xFFFFD700),  // Gold color
  opacity: 0.8,       // Slight transparency
  randomSeed: 42,     // Deterministic
)
```

Preset configuration:
- Type: `star`
- Direction: `random`
- Size: 2-8px
- Speed: 0.5-2 pixels/frame
- Fade: enabled

### confetti

Falling confetti rectangles with rotation:

```dart
ParticleEffect.confetti(
  count: 35,
  colors: [
    Color(0xFFFF6B6B),  // Red
    Color(0xFF4ECDC4),  // Teal
    Color(0xFFFFE66D),  // Yellow
    Color(0xFF95E1D3),  // Mint
    Color(0xFFF38181),  // Coral
    Color(0xFFAA96DA),  // Purple
  ],
  opacity: 1.0,
  randomSeed: 42,
)
```

Preset configuration:
- Type: `confetti`
- Direction: `down`
- Size: 6-12px
- Speed: 2-5 pixels/frame
- Fade: disabled

### snow

Gently falling snowflakes:

```dart
ParticleEffect.snow(
  count: 50,
  color: Colors.white,
  opacity: 0.8,
  randomSeed: 42,
)
```

Preset configuration:
- Type: `circle`
- Direction: `down`
- Size: 2-6px
- Speed: 1-2 pixels/frame
- Fade: disabled

### bubbles

Rising bubbles:

```dart
ParticleEffect.bubbles(
  count: 30,
  color: Colors.white,
  opacity: 0.5,
  randomSeed: 42,
)
```

Preset configuration:
- Type: `circle`
- Direction: `up`
- Size: 4-12px
- Speed: 1-3 pixels/frame
- Fade: disabled

---

## Particle Types

| Type | Description | Visual |
|------|-------------|--------|
| `circle` | Solid circles | ● |
| `star` | 5-pointed stars | ★ |
| `square` | Solid squares | ■ |
| `confetti` | Rotating rectangles | ▬ |

### Custom Particle Type

```dart
ParticleEffect(
  count: 40,
  type: ParticleType.star,
  color: Colors.yellow,
  minSize: 4,
  maxSize: 12,
)
```

---

## Directions

| Direction | Description |
|-----------|-------------|
| `down` | Fall downward (gravity) |
| `up` | Rise upward (bubbles) |
| `left` | Move left |
| `right` | Move right |
| `random` | Random directions |
| `radial` | Explode outward from center |

### Direction Examples

```dart
// Falling particles
ParticleEffect(
  direction: ParticleDirection.down,
  ...
)

// Explosion effect
ParticleEffect(
  direction: ParticleDirection.radial,
  ...
)

// Random floating
ParticleEffect(
  direction: ParticleDirection.random,
  ...
)
```

---

## Examples

### Celebration Confetti

```dart
Scene(
  durationInFrames: 180,
  background: Background.solid(Colors.black),
  children: [
    // Main celebration content
    VCenter(
      child: Text(
        'Congratulations!',
        style: TextStyle(fontSize: 72, color: Colors.white),
      ),
    ),

    // Confetti overlay
    ParticleEffect.confetti(
      count: 60,
      colors: [
        Colors.red,
        Colors.orange,
        Colors.yellow,
        Colors.green,
        Colors.blue,
        Colors.purple,
      ],
    ),
  ],
)
```

### Winter Scene

```dart
Scene(
  durationInFrames: 300,
  background: Background.gradient(
    colors: {
      0: Color(0xFF1a1a2e),
      300: Color(0xFF16213e),
    },
  ),
  children: [
    // Content
    VCenter(child: WinterContent()),

    // Snow overlay
    ParticleEffect.snow(
      count: 80,
      opacity: 0.7,
    ),
  ],
)
```

### Sparkle Highlight

```dart
VStack(
  startFrame: 30,
  endFrame: 150,
  children: [
    // Featured item with sparkles
    Container(
      width: 400,
      height: 300,
      child: Stack(
        children: [
          Image.asset('featured.jpg'),
          Positioned.fill(
            child: ParticleEffect.sparkles(
              count: 20,
              color: Color(0xFFFFD700),
            ),
          ),
        ],
      ),
    ),
  ],
)
```

### Underwater Bubbles

```dart
Scene(
  durationInFrames: 240,
  background: Background.gradient(
    colors: {
      0: Color(0xFF0077B6),
      240: Color(0xFF023E8A),
    },
  ),
  children: [
    // Underwater content
    VCenter(child: UnderwaterScene()),

    // Rising bubbles
    ParticleEffect.bubbles(
      count: 40,
      opacity: 0.4,
    ),
  ],
)
```

### Custom Explosion

```dart
ParticleEffect(
  count: 100,
  type: ParticleType.circle,
  direction: ParticleDirection.radial,
  minSize: 2,
  maxSize: 8,
  minSpeed: 3,
  maxSpeed: 8,
  colors: [
    Colors.orange,
    Colors.red,
    Colors.yellow,
  ],
  fadeOut: true,
  opacity: 0.9,
  randomSeed: 42,
)
```

### Falling Leaves

```dart
ParticleEffect(
  count: 30,
  type: ParticleType.square,  // Leaf-like shapes
  direction: ParticleDirection.down,
  minSize: 8,
  maxSize: 16,
  minSpeed: 1,
  maxSpeed: 2,
  colors: [
    Color(0xFFE76F51),  // Orange
    Color(0xFFF4A261),  // Light orange
    Color(0xFFE9C46A),  // Yellow
    Color(0xFF8B4513),  // Brown
  ],
  opacity: 0.9,
)
```

### Starfield

```dart
ParticleEffect(
  count: 100,
  type: ParticleType.star,
  direction: ParticleDirection.random,
  minSize: 1,
  maxSize: 4,
  minSpeed: 0.2,
  maxSpeed: 0.5,
  color: Colors.white,
  fadeOut: true,
  opacity: 0.8,
)
```

### With Layer Control

```dart
LayerStack(
  children: [
    // Background particles (behind content)
    Layer(
      zIndex: 0,
      child: ParticleEffect.sparkles(count: 15),
    ),

    // Main content
    Layer(
      zIndex: 1,
      child: VCenter(child: MainContent()),
    ),

    // Foreground particles (in front)
    Layer(
      zIndex: 2,
      child: ParticleEffect.confetti(count: 25),
    ),
  ],
)
```

---

## Performance Tips

### Optimize Particle Count

```dart
// Light effect: 15-30 particles
ParticleEffect.sparkles(count: 25)

// Medium effect: 30-50 particles
ParticleEffect.confetti(count: 40)

// Heavy effect: 50-100 particles (use sparingly)
ParticleEffect.snow(count: 80)
```

### Reduce Size Range

Larger particles are more expensive to render:

```dart
// Lighter
ParticleEffect(
  minSize: 2,
  maxSize: 6,
  ...
)

// Heavier
ParticleEffect(
  minSize: 8,
  maxSize: 20,
  ...
)
```

---

## Related

- [EffectOverlay](effect-overlay.md) - Post-processing effects
- [Background](backgrounds.md) - Scene backgrounds
- [LayerStack](../widgets/layout/layer-stack.md) - Layer ordering
- [TimeConsumer](../widgets/core/time-consumer.md) - Frame-based animation
