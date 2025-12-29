# Effects

Fluvie provides visual effects to enhance your video compositions, including particle systems, post-processing overlays, animated backgrounds, and scene transitions.

## Overview

| Topic | Description |
|-------|-------------|
| [ParticleEffect](particle-effect.md) | Animated particle systems |
| [EffectOverlay](effect-overlay.md) | Post-processing overlays |
| [Background](backgrounds.md) | Scene backgrounds |
| [SceneTransition](transitions.md) | Scene transitions |

---

## Quick Examples

### Sparkles

```dart
ParticleEffect.sparkles(
  count: 25,
  color: Colors.yellow,
)
```

### Confetti

```dart
ParticleEffect.confetti(
  count: 40,
  colors: [Colors.red, Colors.blue, Colors.yellow],
)
```

### Film Grain

```dart
EffectOverlay.grain(intensity: 0.06)
```

### Vignette

```dart
EffectOverlay.vignette(intensity: 0.4)
```

### Animated Gradient Background

```dart
Scene(
  background: Background.gradient(
    colors: {
      0: Color(0xFF1a1a2e),
      60: Color(0xFF16213e),
      120: Color(0xFF0f3460),
    },
  ),
  children: [...],
)
```

### Cross-Fade Transition

```dart
Scene(
  transitionIn: SceneTransition.crossFade(durationInFrames: 20),
  children: [...],
)
```

---

## Effect Categories

### Particle Effects

Add dynamic visual elements that move and animate:

| Preset | Description |
|--------|-------------|
| `ParticleEffect.sparkles()` | Glittering star particles |
| `ParticleEffect.confetti()` | Falling confetti rectangles |
| `ParticleEffect.snow()` | Falling snowflakes |
| `ParticleEffect.bubbles()` | Rising bubbles |

### Post-Processing Overlays

Apply cinematic effects on top of content:

| Effect | Description |
|--------|-------------|
| `EffectOverlay.scanlines()` | Horizontal scan lines |
| `EffectOverlay.grain()` | Film grain noise |
| `EffectOverlay.vignette()` | Darkened edges |
| `EffectOverlay.grid()` | Grid overlay |
| `EffectOverlay.crt()` | CRT monitor effect |

### Background Types

Various background options for scenes:

| Type | Description |
|------|-------------|
| `Background.solid()` | Solid color |
| `Background.gradient()` | Animated gradient |
| `Background.image()` | Static image |
| `Background.video()` | Video playback |
| `Background.noise()` | Noise/grain texture |
| `Background.vhs()` | VHS retro effect |

### Scene Transitions

Smooth transitions between scenes:

| Transition | Description |
|------------|-------------|
| `SceneTransition.crossFade()` | Dissolve between scenes |
| `SceneTransition.slideLeft()` | New scene slides in from right |
| `SceneTransition.slideUp()` | New scene slides in from bottom |
| `SceneTransition.scale()` | New scene scales in |
| `SceneTransition.wipe()` | Wipe reveals new scene |
| `SceneTransition.zoomWarp()` | Cinematic zoom transition |
| `SceneTransition.colorBleed()` | Color flows between scenes |

---

## Combining Effects

Stack multiple effects for rich visuals:

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
    // Main content
    VCenter(child: MyContent()),

    // Particles behind content
    ParticleEffect.sparkles(count: 30),

    // Post-processing on top
    EffectOverlay.vignette(intensity: 0.3),
    EffectOverlay.grain(intensity: 0.03),
  ],
)
```

---

## Deterministic Rendering

All effects use `randomSeed` parameters to ensure consistent rendering:

```dart
// Same seed = same particles every render
ParticleEffect.confetti(
  count: 50,
  randomSeed: 42,  // Deterministic
)

// Different seed = different pattern
ParticleEffect.confetti(
  count: 50,
  randomSeed: 123,  // Different pattern
)
```

---

## Performance Considerations

### Particle Count

More particles = more rendering work:

```dart
// Light effect (~25 particles)
ParticleEffect.sparkles(count: 25)

// Heavy effect (~100 particles)
ParticleEffect.confetti(count: 100)
```

### Effect Stacking

Limit overlapping effects:

```dart
// Good: 2-3 overlay effects
LayerStack(
  children: [
    content,
    EffectOverlay.vignette(),
    EffectOverlay.grain(),
  ],
)

// Avoid: Many stacked effects
LayerStack(
  children: [
    content,
    EffectOverlay.scanlines(),
    EffectOverlay.grain(),
    EffectOverlay.vignette(),
    EffectOverlay.crt(),
    ParticleEffect.sparkles(),
    ParticleEffect.confetti(),
  ],
)
```

---

## Related

- [Scene](../widgets/core/scene.md) - Scene widget with backgrounds
- [LayerStack](../widgets/layout/layer-stack.md) - Stacking effects
- [TimeConsumer](../widgets/core/time-consumer.md) - Frame-based animations
