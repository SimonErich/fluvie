# Easing

> **Animation curves for smooth, natural motion**

The `Easing` class provides access to commonly used animation curves with semantic names. These curves transform linear animation progress into shaped motion.

## Table of Contents

- [Overview](#overview)
- [Curve Categories](#curve-categories)
- [All Curves](#all-curves)
- [Visual Guide](#visual-guide)
- [Examples](#examples)
- [Related](#related)

---

## Overview

Easing curves control the rate of change during animations:

```dart
AnimatedProp(
  animation: PropAnimation.slideUp(),
  duration: 30,
  curve: Easing.easeOutCubic,  // Fast start, slow end
  child: Text('Smooth entrance'),
)
```

### Without vs With Easing

```
Linear:        ████████████████████████████████
               constant speed throughout

easeOut:       ████████████▓▓▓▓░░░░░░░░░░░░░
               fast start, gradually slows

easeIn:        ░░░░░░░░░░░░░░░░▓▓▓▓████████████
               slow start, gradually speeds up

easeInOut:     ░░░░░░░▓▓▓████████████▓▓▓░░░░░░░
               slow start, fast middle, slow end
```

---

## Curve Categories

### Standard Curves

Basic easing patterns:

| Curve | Effect | Use Case |
|-------|--------|----------|
| `linear` | Constant speed | Mechanical movement |
| `easeIn` | Slow start | Elements exiting |
| `easeOut` | Slow end | Elements entering |
| `easeInOut` | Slow start and end | Emphasis, transitions |

### Cubic Curves

More pronounced easing:

| Curve | Effect | Use Case |
|-------|--------|----------|
| `easeInCubic` | Pronounced slow start | Dramatic exits |
| `easeOutCubic` | Pronounced slow end | Smooth entrances |
| `easeInOutCubic` | Pronounced both ends | Elegant transitions |

### Exponential Curves

Very dramatic easing:

| Curve | Effect | Use Case |
|-------|--------|----------|
| `easeInExpo` | Very slow start | Building anticipation |
| `easeOutExpo` | Very fast start | Snappy entrances |
| `easeInOutExpo` | Extreme contrast | Dramatic emphasis |

### Back Curves (Overshoot)

Animations that go past their target:

| Curve | Effect | Use Case |
|-------|--------|----------|
| `easeInBack` | Pull back then forward | Wind-up effect |
| `easeOutBack` | Overshoot then settle | Pop into place |
| `easeInOutBack` | Both ends overshoot | Bouncy transitions |

### Elastic Curves

Spring-like oscillation:

| Curve | Effect | Use Case |
|-------|--------|----------|
| `elastic` | Elastic out | Bouncy arrivals |
| `elasticIn` | Elastic in | Building tension |
| `elasticInOut` | Elastic both | Springy emphasis |

### Bounce Curves

Ball-bouncing effect:

| Curve | Effect | Use Case |
|-------|--------|----------|
| `bounce` | Bounce out | Landing impacts |
| `bounceIn` | Bounce in | Approaching impact |
| `bounceInOut` | Bounce both | Playful animations |

### Sine Curves

Gentle, natural motion:

| Curve | Effect | Use Case |
|-------|--------|----------|
| `easeInSine` | Gentle slow start | Subtle entrances |
| `easeOutSine` | Gentle slow end | Subtle exits |
| `easeInOutSine` | Gentle both ends | Natural movement |

### Quart/Quint Curves

Stronger easing variations:

| Curve | Effect | Use Case |
|-------|--------|----------|
| `easeOutQuart` | Stronger than cubic | Quick snap |
| `easeOutQuint` | Strongest standard | Very snappy |

### Circular Curves

Based on circular motion:

| Curve | Effect | Use Case |
|-------|--------|----------|
| `easeInCirc` | Circular ease in | Smooth acceleration |
| `easeOutCirc` | Circular ease out | Smooth deceleration |
| `easeInOutCirc` | Circular both | Orbital motion |

### Step Curves

Instant jumps:

| Curve | Effect | Use Case |
|-------|--------|----------|
| `stepStart` | Jump at start | Instant appear |
| `stepEnd` | Jump at end | Instant disappear |

### Flutter Built-in

Additional Flutter curves:

| Curve | Effect | Use Case |
|-------|--------|----------|
| `fastOutSlowIn` | Material Design standard | Material animations |
| `slowMiddle` | Slow in middle | Dramatic pause |
| `decelerate` | Constant deceleration | Natural stopping |
| `fastLinearToSlowEaseIn` | Fast then eases | Quick starts |

---

## All Curves

### Quick Reference

```dart
// Standard
Easing.linear
Easing.easeIn
Easing.easeOut
Easing.easeInOut

// Cubic
Easing.easeInCubic
Easing.easeOutCubic
Easing.easeInOutCubic

// Exponential
Easing.easeInExpo
Easing.easeOutExpo
Easing.easeInOutExpo

// Back (overshoot)
Easing.easeInBack
Easing.easeOutBack
Easing.easeInOutBack

// Elastic
Easing.elastic
Easing.elasticIn
Easing.elasticInOut

// Bounce
Easing.bounce
Easing.bounceIn
Easing.bounceInOut

// Sine
Easing.easeInSine
Easing.easeOutSine
Easing.easeInOutSine

// Quart/Quint
Easing.easeOutQuart
Easing.easeOutQuint

// Circular
Easing.easeInCirc
Easing.easeOutCirc
Easing.easeInOutCirc

// Step
Easing.stepStart
Easing.stepEnd

// Flutter built-in
Easing.fastOutSlowIn
Easing.slowMiddle
Easing.decelerate
Easing.fastLinearToSlowEaseIn
```

---

## Visual Guide

### Linear vs Eased

```
Progress:  0%   25%   50%   75%   100%
           |     |     |     |     |

linear:    ■─────■─────■─────■─────■
           equal spacing

easeOut:   ■────■───■──■─■
           fast start, slowing down

easeIn:            ■─■──■───■────■
           slow start, speeding up
```

### Overshoot (Back Curves)

```
Target:    ─────────────────────■ (100%)
                               ╱│╲
easeOutBack:              ■───■ │
                         ╱      │
                        ■       │
                       ╱        │ overshoot
Start:     ■──────────          │
           0%                   │
```

### Elastic

```
Target:    ─────────────────────■ (100%)
                          ╱╲╱╲╱│
elastic:              ■──■    ╲│
                     ╱         │
                    ■          │ oscillates
                   ╱           │
Start:     ■──────             │
           0%                  │
```

### Bounce

```
Target:    ─────────────────────■ (100%)
                            ╱│  │
bounce:                   ■╱ │■ │
                         ╱   ╲╱ │ bounces
                        ■       │
                       ╱        │
Start:     ■──────────          │
           0%                   │
```

---

## Examples

### Element Entrance (easeOut)

```dart
// Fast arrival, gentle landing
AnimatedProp(
  animation: PropAnimation.slideUp(),
  duration: 30,
  curve: Easing.easeOutCubic,
  child: Text('Welcome'),
)
```

### Element Exit (easeIn)

```dart
// Gentle start, fast departure
AnimatedProp(
  animation: PropAnimation.slideUp(),
  duration: 25,
  curve: Easing.easeInCubic,
  child: Text('Goodbye'),
)
```

### Pop Effect (easeOutBack)

```dart
// Overshoots then settles
AnimatedProp(
  animation: PropAnimation.zoomIn(start: 0.0),
  duration: 35,
  curve: Easing.easeOutBack,
  child: Icon(Icons.check, size: 64, color: Colors.green),
)
```

### Bouncy Landing (bounce)

```dart
// Ball drop effect
AnimatedProp(
  animation: PropAnimation.slideDown(distance: 200),
  duration: 60,
  curve: Easing.bounce,
  child: Container(
    width: 50,
    height: 50,
    decoration: BoxDecoration(
      color: Colors.red,
      shape: BoxShape.circle,
    ),
  ),
)
```

### Spring Effect (elastic)

```dart
// Springy scale animation
AnimatedProp(
  animation: PropAnimation.zoomIn(start: 0.3),
  duration: 50,
  curve: Easing.elastic,
  child: Text('Boing!', style: TextStyle(fontSize: 48)),
)
```

### Snappy Entrance (easeOutExpo)

```dart
// Very fast start
AnimatedProp(
  animation: PropAnimation.slideLeft(distance: 300),
  duration: 40,
  curve: Easing.easeOutExpo,
  child: Card(child: ListTile(title: Text('Quick!'))),
)
```

### Smooth Transition (easeInOutCubic)

```dart
// Elegant scene transition
AnimatedProp(
  animation: PropAnimation.fade(start: 0.0, end: 1.0),
  duration: 45,
  curve: Easing.easeInOutCubic,
  child: newSceneContent,
)
```

### With interpolate()

```dart
TimeConsumer(
  builder: (context, frame, child) {
    final scale = interpolate(
      frame,
      [0, 30],
      [0.5, 1.0],
      curve: Easing.easeOutBack,
    );
    return Transform.scale(scale: scale, child: child);
  },
  child: content,
)
```

### Staggered List with Curve

```dart
VColumn(
  stagger: StaggerConfig.slideUp(
    delay: 8,
    duration: 30,
    curve: Easing.easeOutCubic,
  ),
  children: items,
)
```

---

## Choosing the Right Curve

### For Entrances

| Situation | Recommended Curve |
|-----------|-------------------|
| Standard entrance | `easeOutCubic` |
| Quick entrance | `easeOutExpo` |
| Playful entrance | `easeOutBack` |
| Bouncy entrance | `elastic` or `bounce` |
| Subtle entrance | `easeOutSine` |

### For Exits

| Situation | Recommended Curve |
|-----------|-------------------|
| Standard exit | `easeInCubic` |
| Quick exit | `easeInExpo` |
| Anticipation exit | `easeInBack` |
| Subtle exit | `easeInSine` |

### For Emphasis

| Situation | Recommended Curve |
|-----------|-------------------|
| Pop/attention | `easeOutBack` |
| Spring effect | `elastic` |
| Impact | `bounce` |
| Smooth highlight | `easeInOutCubic` |

### For Continuous Motion

| Situation | Recommended Curve |
|-----------|-------------------|
| Mechanical | `linear` |
| Natural | `easeInOutSine` |
| Pulsing | `easeInOutCubic` |

---

## Custom Curves

Create custom cubic bezier curves:

```dart
// Custom curve using Flutter's Cubic
const customCurve = Cubic(0.25, 0.1, 0.25, 1.0);

AnimatedProp(
  curve: customCurve,
  ...
)
```

Use tools like [cubic-bezier.com](https://cubic-bezier.com/) to design curves.

---

## Related

- [PropAnimation](prop-animation.md) - Animation class
- [interpolate()](interpolate.md) - Keyframe animation
- [StaggerConfig](stagger-config.md) - Staggered animations
- [AnimatedProp](../widgets/core/animated-prop.md) - Animation widget
