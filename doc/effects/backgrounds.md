# Background

> **Scene backgrounds with colors, gradients, images, and effects**

The `Background` class provides various background types for scenes including solid colors, animated gradients, images, videos, and special effects like noise and VHS.

## Table of Contents

- [Overview](#overview)
- [Background Types](#background-types)
- [Gradient Animation](#gradient-animation)
- [Examples](#examples)
- [Related](#related)

---

## Overview

Set backgrounds on `Scene` widgets:

```dart
Scene(
  durationInFrames: 180,
  background: Background.solid(Colors.black),
  children: [...],
)
```

---

## Background Types

### Solid Color

Simple single-color background:

```dart
Background.solid(Colors.black)

Background.solid(Color(0xFF1a1a2e))
```

### Animated Gradient

Color that transitions over frames:

```dart
Background.gradient(
  colors: {
    0: Color(0xFF1a1a2e),    // Start color
    60: Color(0xFF16213e),   // At frame 60
    120: Color(0xFF0f3460),  // At frame 120
  },
)
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `colors` | `Map<int, Color>` | **required** | Frame -> color keyframes |
| `type` | `GradientType` | `linear` | Gradient type |
| `begin` | `Alignment` | `topCenter` | Start alignment |
| `end` | `Alignment` | `bottomCenter` | End alignment |

**Gradient Types:**
- `GradientType.linear` - Linear gradient
- `GradientType.radial` - Radial from center
- `GradientType.sweep` - Sweep around center

### Image Background

Static image as background:

```dart
Background.image(
  assetPath: 'assets/background.jpg',
  fit: BoxFit.cover,
)
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `assetPath` | `String` | **required** | Path to image asset |
| `fit` | `BoxFit` | `cover` | How image fits |

### Video Background

Video playback as background:

```dart
Background.video(
  assetPath: 'assets/background.mp4',
  fit: BoxFit.cover,
)
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `assetPath` | `String` | **required** | Path to video asset |
| `fit` | `BoxFit` | `cover` | How video fits |

### Noise Background

Animated noise/grain texture:

```dart
Background.noise(
  intensity: 0.05,
  color: Colors.white,
  animate: true,
  animationSpeed: 1,
  seed: 42,
)
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `intensity` | `double` | `0.05` | Noise visibility |
| `color` | `Color` | `white` | Noise color |
| `seed` | `int` | `42` | Random seed |
| `animate` | `bool` | `true` | Animate the noise |
| `animationSpeed` | `int` | `1` | Animation speed |

### VHS Background

Retro VHS video tape effect:

```dart
Background.vhs(
  baseColor: Color(0xFF1a1a1a),
  intensity: 0.5,
  showScanlines: true,
  showChromatic: true,
  showTracking: true,
  animate: true,
  seed: 42,
)
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `baseColor` | `Color` | dark gray | Base background color |
| `intensity` | `double` | `0.5` | Overall effect intensity |
| `showScanlines` | `bool` | `true` | Show scan lines |
| `showChromatic` | `bool` | `true` | Show chromatic aberration |
| `showTracking` | `bool` | `true` | Show tracking distortion |
| `animate` | `bool` | `true` | Animate effects |
| `seed` | `int` | `42` | Random seed |

---

## Gradient Animation

### How It Works

Colors are keyframed to specific frames and interpolated:

```dart
Background.gradient(
  colors: {
    0: Colors.red,     // Red at frame 0
    60: Colors.blue,   // Blue at frame 60
    120: Colors.green, // Green at frame 120
  },
)
```

**Timeline:**
```
Frame:  0      30      60      90      120
        |       |       |       |       |
Color:  Red ───> Purple ───> Blue ───> Teal ───> Green
```

### Single Color Gradient

With one keyframe, creates a simple gradient from color to slightly darker:

```dart
Background.gradient(
  colors: {0: Color(0xFF1a1a2e)},
)
```

### Multi-Stop Gradient

Add multiple keyframes for complex color transitions:

```dart
Background.gradient(
  colors: {
    0: Color(0xFF1a1a2e),
    30: Color(0xFF16213e),
    60: Color(0xFF0f3460),
    90: Color(0xFF16213e),
    120: Color(0xFF1a1a2e),  // Loop back
  },
)
```

### Gradient Direction

Control the gradient direction:

```dart
// Top to bottom (default)
Background.gradient(
  colors: {...},
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
)

// Left to right
Background.gradient(
  colors: {...},
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
)

// Diagonal
Background.gradient(
  colors: {...},
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
)
```

### Radial Gradient

Gradient radiating from center:

```dart
Background.gradient(
  colors: {
    0: Color(0xFF1a1a2e),
    60: Color(0xFF16213e),
  },
  type: GradientType.radial,
)
```

---

## Examples

### Simple Dark Background

```dart
Scene(
  durationInFrames: 180,
  background: Background.solid(Color(0xFF0a0a0a)),
  children: [...],
)
```

### Animated Night Sky

```dart
Scene(
  durationInFrames: 240,
  background: Background.gradient(
    colors: {
      0: Color(0xFF0d1b2a),   // Deep blue
      120: Color(0xFF1b263b), // Lighter blue
      240: Color(0xFF0d1b2a), // Back to deep blue
    },
  ),
  children: [
    ParticleEffect(
      type: ParticleType.star,
      count: 50,
      opacity: 0.7,
    ),
  ],
)
```

### Sunset Transition

```dart
Scene(
  durationInFrames: 180,
  background: Background.gradient(
    colors: {
      0: Color(0xFFFF9A8B),   // Coral
      45: Color(0xFFFF6A88),  // Pink
      90: Color(0xFFFF99AC),  // Light pink
      135: Color(0xFF7B68EE), // Purple
      180: Color(0xFF1a1a2e), // Dark (night)
    },
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  ),
  children: [...],
)
```

### Photo Background

```dart
Scene(
  durationInFrames: 180,
  background: Background.image(
    assetPath: 'assets/landscape.jpg',
    fit: BoxFit.cover,
  ),
  children: [
    // Overlay to ensure text readability
    Container(color: Colors.black.withOpacity(0.3)),
    VCenter(child: Text('Title')),
  ],
)
```

### Retro VHS Look

```dart
Scene(
  durationInFrames: 180,
  background: Background.vhs(
    baseColor: Color(0xFF1a1a1a),
    intensity: 0.6,
    showScanlines: true,
    showChromatic: true,
    showTracking: true,
  ),
  children: [
    VCenter(
      child: Text(
        'PLAY ▶',
        style: TextStyle(
          fontSize: 48,
          color: Colors.white,
          fontFamily: 'VCR',
        ),
      ),
    ),
  ],
)
```

### Noisy Texture

```dart
Scene(
  durationInFrames: 180,
  background: Background.noise(
    intensity: 0.08,
    color: Color(0xFF333333),
    animate: true,
  ),
  children: [...],
)
```

### Layered Background

Combine background with overlays:

```dart
Scene(
  durationInFrames: 180,
  background: Background.gradient(
    colors: {
      0: Color(0xFF1a1a2e),
      180: Color(0xFF16213e),
    },
  ),
  children: [
    // Background particles
    ParticleEffect.sparkles(count: 20),

    // Main content
    VCenter(child: Content()),

    // Vignette on top
    EffectOverlay.vignette(intensity: 0.3),
  ],
)
```

### Breathing Background

Pulsing color animation:

```dart
Scene(
  durationInFrames: 120,
  background: Background.gradient(
    colors: {
      0: Color(0xFF1a1a2e),
      30: Color(0xFF2a2a4e),  // Brighten
      60: Color(0xFF1a1a2e),  // Return
      90: Color(0xFF2a2a4e),  // Brighten
      120: Color(0xFF1a1a2e), // Return
    },
  ),
  children: [...],
)
```

---

## Custom Backgrounds

Create custom backgrounds by extending `Background`:

```dart
class MyCustomBackground extends Background {
  final Color color1;
  final Color color2;

  const MyCustomBackground({
    required this.color1,
    required this.color2,
  });

  @override
  Widget build(BuildContext context, int sceneLength) {
    return TimeConsumer(
      builder: (context, frame, _) {
        // Custom animation logic
        final t = (frame / sceneLength).clamp(0.0, 1.0);
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.lerp(color1, color2, t)!,
                Color.lerp(color2, color1, t)!,
              ],
            ),
          ),
        );
      },
    );
  }
}
```

---

## Related

- [Scene](../widgets/core/scene.md) - Scene widget
- [EffectOverlay](effect-overlay.md) - Post-processing effects
- [ParticleEffect](particle-effect.md) - Particle systems
- [TimeConsumer](../widgets/core/time-consumer.md) - Frame-based animation
