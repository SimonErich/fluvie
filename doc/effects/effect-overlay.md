# EffectOverlay

> **Post-processing visual effects for cinematic looks**

`EffectOverlay` renders various post-processing effects like scanlines, film grain, vignette, and CRT monitor effects. These are rendered as overlays and can be combined for unique visual styles.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Effect Types](#effect-types)
- [Examples](#examples)
- [Combining Effects](#combining-effects)
- [Related](#related)

---

## Overview

Apply cinematic effects on top of your content:

```dart
Stack(
  children: [
    // Your content
    MyContent(),

    // Effect overlays
    EffectOverlay.vignette(intensity: 0.4),
    EffectOverlay.grain(intensity: 0.05),
  ],
)
```

---

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `type` | `EffectType` | **required** | Type of effect |
| `intensity` | `double` | `0.5` | Effect strength (0.0 - 1.0) |
| `color` | `Color?` | `null` | Color for effects that use it |
| `randomSeed` | `int?` | `null` | Seed for grain effect |

---

## Effect Types

### Scanlines

Horizontal scan lines for a CRT/retro monitor look:

```dart
EffectOverlay.scanlines(
  intensity: 0.02,  // Very subtle
)
```

| Intensity | Effect |
|-----------|--------|
| `0.01` | Barely visible |
| `0.02` | Subtle (default) |
| `0.05` | Noticeable |
| `0.1` | Strong |

**Visual:**
```
Content with scanlines:
══════════════════════
══════════════════════
══════════════════════
(subtle horizontal lines)
```

### Grain

Film grain noise effect that animates each frame:

```dart
EffectOverlay.grain(
  intensity: 0.06,   // Subtle grain
  randomSeed: 42,    // Optional: consistent pattern
)
```

| Intensity | Effect |
|-----------|--------|
| `0.03` | Film-like, subtle |
| `0.06` | Noticeable (default) |
| `0.10` | Strong grain |
| `0.15` | Very noisy |

The grain animates automatically - each frame has different noise to simulate film grain authentically.

### Vignette

Darkened edges that draw focus to the center:

```dart
EffectOverlay.vignette(
  intensity: 0.4,  // Moderate darkening
)
```

| Intensity | Effect |
|-----------|--------|
| `0.2` | Very subtle |
| `0.4` | Moderate (default) |
| `0.6` | Strong |
| `0.8` | Dramatic |

**Visual:**
```
┌─────────────────────┐
│░░░░░         ░░░░░│
│░░░             ░░░│
│░                 ░│
│                   │ <- Center bright
│░                 ░│
│░░░             ░░░│
│░░░░░         ░░░░░│
└─────────────────────┘
```

### Grid

Grid overlay for a technical/futuristic look:

```dart
EffectOverlay.grid(
  intensity: 0.05,
  color: Colors.white,
)
```

| Intensity | Effect |
|-----------|--------|
| `0.03` | Barely visible |
| `0.05` | Subtle (default) |
| `0.10` | Visible |
| `0.20` | Prominent |

**Visual:**
```
┌───┬───┬───┬───┬───┐
│   │   │   │   │   │
├───┼───┼───┼───┼───┤
│   │   │   │   │   │
├───┼───┼───┼───┼───┤
│   │   │   │   │   │
└───┴───┴───┴───┴───┘
```

### CRT

Combined CRT monitor effect (scanlines + vignette):

```dart
EffectOverlay.crt(
  intensity: 0.3,
)
```

This combines:
- Scanlines at `intensity * 0.3`
- Vignette at `intensity * 0.5`

Creates an authentic retro CRT monitor appearance.

### Chromatic Aberration

RGB color separation at edges:

```dart
EffectOverlay(
  type: EffectType.chromaticAberration,
  intensity: 0.3,
)
```

Creates red/cyan color fringing at the edges of the frame, simulating lens distortion.

---

## Examples

### Film Look

Classic film aesthetic:

```dart
Scene(
  durationInFrames: 180,
  background: Background.solid(Colors.black),
  children: [
    // Content
    VCenter(child: MyContent()),

    // Film effects
    EffectOverlay.grain(intensity: 0.05),
    EffectOverlay.vignette(intensity: 0.35),
  ],
)
```

### Retro TV

Old CRT television look:

```dart
Scene(
  durationInFrames: 180,
  background: Background.solid(Color(0xFF1a1a1a)),
  children: [
    // Content with slight padding (like TV safe zone)
    VPadding(
      padding: EdgeInsets.all(40),
      child: MyContent(),
    ),

    // CRT effect
    EffectOverlay.crt(intensity: 0.4),
  ],
)
```

### Sci-Fi Interface

Futuristic HUD look:

```dart
Scene(
  durationInFrames: 180,
  background: Background.solid(Color(0xFF0a0a0a)),
  children: [
    // Content
    VCenter(child: DataDisplay()),

    // Sci-fi effects
    EffectOverlay.grid(
      intensity: 0.08,
      color: Color(0xFF00ff88),  // Green grid
    ),
    EffectOverlay.scanlines(intensity: 0.03),
    EffectOverlay.vignette(intensity: 0.5),
  ],
)
```

### Horror/Tension

Dark, unsettling atmosphere:

```dart
Scene(
  durationInFrames: 180,
  background: Background.solid(Colors.black),
  children: [
    // Content
    VCenter(child: HorrorContent()),

    // Tension effects
    EffectOverlay.vignette(intensity: 0.7),  // Heavy vignette
    EffectOverlay.grain(intensity: 0.08),    // Noticeable grain
  ],
)
```

### VHS/Nostalgic

Vintage video tape look:

```dart
Scene(
  durationInFrames: 180,
  background: Background.vhs(intensity: 0.5),
  children: [
    // Content
    VCenter(child: VintageContent()),

    // Additional effects
    EffectOverlay.scanlines(intensity: 0.04),
    EffectOverlay.grain(intensity: 0.06),
  ],
)
```

### Subtle Enhancement

Minimal effects for polish:

```dart
Scene(
  durationInFrames: 180,
  children: [
    VCenter(child: Content()),

    // Subtle polish
    EffectOverlay.vignette(intensity: 0.2),
    EffectOverlay.grain(intensity: 0.02),  // Very subtle
  ],
)
```

---

## Combining Effects

### Layering Order

Effects are applied in order - later effects overlay earlier ones:

```dart
Stack(
  children: [
    Content(),

    // Order matters:
    EffectOverlay.grain(),      // 1. Grain first
    EffectOverlay.scanlines(),  // 2. Scanlines on top
    EffectOverlay.vignette(),   // 3. Vignette last (darkens everything)
  ],
)
```

### Recommended Combinations

**Film Look:**
```dart
EffectOverlay.grain(intensity: 0.04)
EffectOverlay.vignette(intensity: 0.3)
```

**Retro/VHS:**
```dart
EffectOverlay.scanlines(intensity: 0.03)
EffectOverlay.grain(intensity: 0.06)
EffectOverlay.vignette(intensity: 0.4)
```

**Clean/Modern:**
```dart
EffectOverlay.vignette(intensity: 0.15)
```

**Sci-Fi:**
```dart
EffectOverlay.grid(intensity: 0.05, color: accentColor)
EffectOverlay.scanlines(intensity: 0.02)
```

### Intensity Balance

When combining effects, reduce individual intensities:

```dart
// Single effect - full intensity
EffectOverlay.vignette(intensity: 0.4)

// Multiple effects - reduce each
EffectOverlay.grain(intensity: 0.03)      // Reduced
EffectOverlay.vignette(intensity: 0.25)   // Reduced
EffectOverlay.scanlines(intensity: 0.015) // Reduced
```

---

## Performance Considerations

### Grain Effect

Grain recalculates each frame and can be expensive:

```dart
// Lighter: Lower intensity = less visible pixels
EffectOverlay.grain(intensity: 0.03)

// Heavier: Higher intensity
EffectOverlay.grain(intensity: 0.10)
```

### Multiple Overlays

Each overlay adds rendering cost:

```dart
// Good: 2-3 effects
Stack(
  children: [
    content,
    EffectOverlay.vignette(),
    EffectOverlay.grain(),
  ],
)

// Expensive: Many effects
Stack(
  children: [
    content,
    EffectOverlay.scanlines(),
    EffectOverlay.grain(),
    EffectOverlay.vignette(),
    EffectOverlay.grid(),
    EffectOverlay.crt(),
  ],
)
```

---

## Related

- [ParticleEffect](particle-effect.md) - Particle systems
- [Background](backgrounds.md) - Scene backgrounds
- [Scene](../widgets/core/scene.md) - Scene widget
- [LayerStack](../widgets/layout/layer-stack.md) - Layering content
