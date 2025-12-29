# AnimatedText

> **Text with built-in animation support**

`AnimatedText` combines text rendering with `PropAnimation` for easy animated text effects like fade-in, slide-up, scale, and more.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Constructors](#constructors)
- [Examples](#examples)
- [Custom Animations](#custom-animations)
- [Related](#related)

---

## Overview

`AnimatedText` provides the easiest way to add animated text to your video:

```dart
AnimatedText(
  'Hello World',
  style: TextStyle(fontSize: 48, color: Colors.white),
  animation: PropAnimation.slideUpFade(),
  duration: 30,
)
```

### When to Use

Use `AnimatedText` when you need:
- Text that animates in (fade, slide, scale)
- Simple text animations without complex timing
- Quick prototyping of text effects

Use `FadeText` with `TimeConsumer` for more complex custom animations.

---

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `text` | `String` | **required** | Text to display |
| `style` | `TextStyle?` | `null` | Text styling |
| `animation` | `PropAnimation?` | `null` | Animation to apply |
| `startFrame` | `int` | `0` | Frame to start animation |
| `duration` | `int` | `30` | Animation duration in frames |
| `curve` | `Curve` | `easeOut` | Animation easing |
| `textAlign` | `TextAlign?` | `null` | Text alignment |
| `maxLines` | `int?` | `null` | Maximum lines |
| `overflow` | `TextOverflow?` | `null` | Overflow handling |

---

## Constructors

### Default Constructor

Full control with custom animation:

```dart
AnimatedText(
  'Hello',
  animation: PropAnimation.slideUpFade(),
  startFrame: 30,
  duration: 45,
  curve: Curves.easeOutCubic,
)
```

### AnimatedText.fadeIn

Simple fade in:

```dart
AnimatedText.fadeIn(
  'Fading text',
  duration: 30,
)
```

### AnimatedText.slideUp

Slide up into view:

```dart
AnimatedText.slideUp(
  'Sliding up',
  distance: 40,  // Pixels to slide
  duration: 30,
)
```

### AnimatedText.slideUpFade

Slide up with fade (most common):

```dart
AnimatedText.slideUpFade(
  'Slide and fade',
  distance: 30,
  duration: 30,
)
```

### AnimatedText.scale

Scale in:

```dart
AnimatedText.scale(
  'Scaling',
  start: 0.5,  // Start at 50% size
  duration: 30,
)
```

### AnimatedText.scaleFade

Scale with fade:

```dart
AnimatedText.scaleFade(
  'Scale and fade',
  startScale: 0.8,
  duration: 30,
)
```

---

## Examples

### Basic Fade In

```dart
AnimatedText.fadeIn(
  'Welcome',
  style: TextStyle(
    fontSize: 72,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  ),
  duration: 30,
)
```

### Delayed Animation

```dart
AnimatedText.slideUpFade(
  'Appears after 1 second',
  startFrame: 30,  // 1 second at 30fps
  duration: 25,
  style: TextStyle(fontSize: 48, color: Colors.white),
)
```

### In a Scene

```dart
Scene(
  durationInFrames: 150,
  background: Background.solid(Colors.black),
  children: [
    VCenter(
      child: VColumn(
        spacing: 20,
        children: [
          AnimatedText.slideUpFade(
            '2024',
            startFrame: 0,
            duration: 30,
            style: TextStyle(
              fontSize: 120,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          AnimatedText.slideUpFade(
            'YOUR YEAR',
            startFrame: 15,  // Delayed
            duration: 30,
            style: TextStyle(
              fontSize: 48,
              color: Colors.white70,
            ),
          ),
          AnimatedText.slideUpFade(
            'IN REVIEW',
            startFrame: 30,  // More delayed
            duration: 30,
            style: TextStyle(
              fontSize: 48,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    ),
  ],
)
```

### With VColumn Stagger

Combine with `VColumn` stagger for automatic delays:

```dart
VColumn(
  spacing: 15,
  stagger: StaggerConfig.slideUp(delay: 12),
  children: [
    AnimatedText('Line 1', style: titleStyle),
    AnimatedText('Line 2', style: subtitleStyle),
    AnimatedText('Line 3', style: subtitleStyle),
  ],
)
```

### Different Curves

```dart
// Quick start, slow end
AnimatedText.slideUpFade(
  'Ease out',
  curve: Curves.easeOutCubic,
  duration: 30,
)

// Slow start, quick end
AnimatedText.slideUpFade(
  'Ease in',
  curve: Curves.easeInCubic,
  duration: 30,
)

// Bouncy
AnimatedText.scaleFade(
  'Bouncy!',
  curve: Curves.elasticOut,
  duration: 60,
)
```

---

## Custom Animations

Use `PropAnimation` classes for custom effects:

### Translate Animation

```dart
AnimatedText(
  'Moving text',
  animation: TranslateAnimation(
    start: Offset(-100, 0),  // Start 100px left
    end: Offset.zero,         // End at normal position
  ),
  duration: 30,
)
```

### Rotate Animation

```dart
AnimatedText(
  'Spinning',
  animation: RotateAnimation(
    start: -0.1,  // Start rotated
    end: 0,       // End upright
  ),
  duration: 30,
)
```

### Combined Animation

```dart
AnimatedText(
  'Complex animation',
  animation: CombinedAnimation([
    TranslateAnimation(start: Offset(0, 50), end: Offset.zero),
    ScaleAnimation(start: 0.8, end: 1.0),
    FadeAnimation(start: 0, end: 1),
    RotateAnimation(start: -0.05, end: 0),
  ]),
  duration: 45,
  curve: Curves.easeOutBack,
)
```

---

## Animation Timeline

```
Frame:    0    10   20   30   40   50
          |     |    |    |    |    |

startFrame: 0, duration: 30
Animation: ████████████████████
Progress:  0%              100%

startFrame: 15, duration: 30
Animation:       ████████████████████
Progress:        0%              100%
```

### Before Animation

When `frame < startFrame`, the text is in its starting state (e.g., invisible for fade, offset for slide).

### After Animation

When `frame >= startFrame + duration`, the text is in its final state (fully visible, at normal position).

---

## Related

- [PropAnimation](../../animations/prop-animation.md) - Animation classes
- [TypewriterText](typewriter-text.md) - Character-by-character reveal
- [CounterText](counter-text.md) - Number counting
- [FadeText](fade-text.md) - Base fade-aware text
