# Entry Animations

> **Specialized reveal animations with dramatic effects**

`EntryAnimation` extends `PropAnimation` with specialized reveal effects designed for element entrances. These animations include elastic bounces, strobe reveals, glitch effects, and masked wipes.

## Table of Contents

- [Overview](#overview)
- [Animation Types](#animation-types)
- [Properties](#properties)
- [Examples](#examples)
- [Related](#related)

---

## Overview

Entry animations reveal elements with cinematic effects:

```dart
AnimatedProp(
  animation: EntryAnimation.elasticPop(overshoot: 1.15),
  duration: 45,
  child: Text('Pop!'),
)
```

Each entry animation has:
- `defaultDuration` - Recommended animation length in frames
- `recommendedCurve` - Suggested easing curve

---

## Animation Types

### ElasticPop

A spring-like pop effect that scales up with overshoot, then settles:

```dart
EntryAnimation.elasticPop(
  overshoot: 1.1,              // Maximum scale (default: 1.1)
  startScale: 0.0,             // Starting scale (default: 0.0)
  alignment: Alignment.center, // Scale origin
)
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `overshoot` | `double` | `1.1` | Peak scale before settling to 1.0 |
| `startScale` | `double` | `0.0` | Initial scale |
| `alignment` | `Alignment` | `center` | Scale origin |

**Animation Timeline:**
```
Progress:  0%        70%        100%
Scale:     0.0 ────> 1.1 ────> 1.0
                     ↑          ↑
                overshoot    settle
```

**Default Duration:** 45 frames
**Recommended Curve:** `Curves.easeOutBack`

---

### StrobeReveal

A flickering strobe effect that dampens over time:

```dart
EntryAnimation.strobeReveal(
  flickerCount: 5,        // Number of flicker cycles (default: 5)
  flickerIntensity: 0.7,  // Strength of flicker 0-1 (default: 0.7)
)
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `flickerCount` | `int` | `5` | Number of complete flicker cycles |
| `flickerIntensity` | `double` | `0.7` | Intensity of the effect (0.0-1.0) |

**Animation Timeline:**
```
Progress:  0%                              100%
Opacity:   ╱╲╱╲╱╲╱╲ ───────────────────── 1.0
           ↑ rapid flicker    ↑ dampened    ↑ settled
```

**Default Duration:** 30 frames
**Recommended Curve:** `Curves.linear`

---

### GlitchSlide

A slide animation with RGB chromatic aberration glitch effect:

```dart
EntryAnimation.glitchSlide(
  direction: EntrySlideDirection.fromLeft,  // Slide direction
  distance: 200,                            // Slide distance in pixels
  rgbOffset: 8,                             // RGB channel separation
  echoOpacity: 0.4,                         // Opacity of RGB echoes
)
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `direction` | `EntrySlideDirection` | `fromLeft` | Direction to slide from |
| `distance` | `double` | `200` | Distance in pixels |
| `rgbOffset` | `double` | `8` | RGB channel separation |
| `echoOpacity` | `double` | `0.4` | Echo layer opacity |

**Available Directions:**
- `EntrySlideDirection.fromLeft`
- `EntrySlideDirection.fromRight`
- `EntrySlideDirection.fromTop`
- `EntrySlideDirection.fromBottom`

**Animation Timeline:**
```
Progress:   0%           70%         100%
Position:   -200px ─────> 0px ─────> 0px
RGB Glitch: [STRONG] ───> [FADE] ──> [NONE]
```

**Default Duration:** 40 frames
**Recommended Curve:** `Curves.easeOutExpo`

---

### MaskedWipe

Reveals through an expanding geometric shape:

```dart
EntryAnimation.maskedWipe(
  shape: WipeShape.circle,     // Shape of the mask
  origin: Alignment.center,    // Where mask expands from
)
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `shape` | `WipeShape` | `circle` | Mask shape |
| `origin` | `Alignment` | `center` | Expansion origin |

**Available Shapes:**
- `WipeShape.circle` - Circular reveal
- `WipeShape.star` - 5-point star reveal
- `WipeShape.diamond` - Diamond/rhombus reveal
- `WipeShape.hexagon` - Hexagonal reveal
- `WipeShape.heart` - Heart-shaped reveal

**Animation Timeline:**
```
Progress:  0%     50%     100%
Shape:     ·  →   ◉   →   ████
          tiny  medium   full
```

**Default Duration:** 45 frames
**Recommended Curve:** `Curves.easeOutCubic`

---

## Properties

All entry animations share these properties:

| Property | Type | Description |
|----------|------|-------------|
| `defaultDuration` | `int` | Recommended animation length |
| `recommendedCurve` | `Curve` | Suggested easing curve |

Access them to use recommended settings:

```dart
final animation = EntryAnimation.elasticPop();

AnimatedProp(
  animation: animation,
  duration: animation.defaultDuration,
  curve: animation.recommendedCurve,
  child: MyWidget(),
)
```

---

## Examples

### Elastic Pop Title

```dart
Scene(
  durationInFrames: 120,
  background: Background.solid(Colors.black),
  children: [
    VCenter(
      startFrame: 30,
      child: AnimatedProp(
        animation: EntryAnimation.elasticPop(overshoot: 1.2),
        duration: 45,
        startFrame: 30,
        child: Text(
          'Welcome!',
          style: TextStyle(
            fontSize: 72,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    ),
  ],
)
```

### Strobe Reveal Text

```dart
AnimatedProp(
  animation: EntryAnimation.strobeReveal(
    flickerCount: 8,
    flickerIntensity: 0.8,
  ),
  duration: 35,
  startFrame: 0,
  child: Text(
    'ALERT',
    style: TextStyle(
      fontSize: 64,
      color: Colors.red,
      fontWeight: FontWeight.w900,
    ),
  ),
)
```

### Glitch Slide Hero

```dart
VPositioned(
  left: 0,
  right: 0,
  top: 100,
  startFrame: 0,
  child: AnimatedProp(
    animation: EntryAnimation.glitchSlide(
      direction: EntrySlideDirection.fromLeft,
      distance: 300,
      rgbOffset: 12,
    ),
    duration: 50,
    curve: Easing.easeOutExpo,
    child: Text(
      'CYBERPUNK',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 80,
        fontWeight: FontWeight.w900,
        color: Colors.cyan,
        letterSpacing: 8,
      ),
    ),
  ),
)
```

### Star Wipe Reveal

```dart
AnimatedProp(
  animation: EntryAnimation.maskedWipe(
    shape: WipeShape.star,
    origin: Alignment.center,
  ),
  duration: 60,
  curve: Easing.easeOutCubic,
  child: Image.asset(
    'assets/photo.jpg',
    width: 400,
    height: 400,
    fit: BoxFit.cover,
  ),
)
```

### Heart Reveal Photo

```dart
VCenter(
  startFrame: 30,
  child: AnimatedProp(
    animation: EntryAnimation.maskedWipe(
      shape: WipeShape.heart,
      origin: Alignment.center,
    ),
    duration: 50,
    startFrame: 30,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.asset(
        'assets/loved_memory.jpg',
        width: 500,
        height: 500,
        fit: BoxFit.cover,
      ),
    ),
  ),
)
```

### Sequential Entry Effects

```dart
Scene(
  durationInFrames: 180,
  children: [
    // First: Circle wipe for image
    VPositioned(
      left: 100,
      top: 100,
      startFrame: 0,
      child: AnimatedProp(
        animation: EntryAnimation.maskedWipe(
          shape: WipeShape.circle,
        ),
        duration: 45,
        child: Image.asset('assets/profile.jpg', width: 200),
      ),
    ),

    // Then: Elastic pop for name
    VPositioned(
      left: 100,
      top: 320,
      startFrame: 30,
      child: AnimatedProp(
        animation: EntryAnimation.elasticPop(overshoot: 1.15),
        duration: 40,
        startFrame: 30,
        child: Text('John Doe', style: TextStyle(fontSize: 32)),
      ),
    ),

    // Finally: Glitch slide for title
    VPositioned(
      left: 100,
      top: 360,
      startFrame: 50,
      child: AnimatedProp(
        animation: EntryAnimation.glitchSlide(
          direction: EntrySlideDirection.fromRight,
          distance: 150,
        ),
        duration: 35,
        startFrame: 50,
        child: Text('Developer', style: TextStyle(fontSize: 20)),
      ),
    ),
  ],
)
```

### Different Wipe Origins

```dart
// Reveal from top-left corner
EntryAnimation.maskedWipe(
  shape: WipeShape.circle,
  origin: Alignment.topLeft,
)

// Reveal from bottom
EntryAnimation.maskedWipe(
  shape: WipeShape.diamond,
  origin: Alignment.bottomCenter,
)

// Reveal from right side
EntryAnimation.maskedWipe(
  shape: WipeShape.hexagon,
  origin: Alignment.centerRight,
)
```

### Combining Entry with PropAnimation

Entry animations extend PropAnimation, so you can combine them:

```dart
PropAnimation.combine([
  EntryAnimation.elasticPop(startScale: 0.5),
  PropAnimation.slideUp(distance: 30),
])
```

---

## Custom Entry Animations

Create custom entry animations by extending `EntryAnimation`:

```dart
class SpinRevealAnimation extends EntryAnimation {
  final double rotations;

  const SpinRevealAnimation({this.rotations = 2});

  @override
  int get defaultDuration => 40;

  @override
  Curve get recommendedCurve => Curves.easeOutCubic;

  @override
  Widget apply(Widget child, double progress) {
    final angle = rotations * 2 * 3.14159 * (1 - progress);
    final scale = progress;
    final opacity = progress;

    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Transform.rotate(
          angle: angle,
          child: child,
        ),
      ),
    );
  }
}
```

---

## Related

- [PropAnimation](prop-animation.md) - Base animation class
- [Easing](easing.md) - Animation curves
- [AnimatedProp](../widgets/core/animated-prop.md) - Animation widget
- [AnimatedText](../widgets/text/animated-text.md) - Text animations
