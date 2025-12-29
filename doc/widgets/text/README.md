# Text Widgets

Text widgets in Fluvie provide animated text rendering optimized for video output. They avoid Flutter's `saveLayer()` calls that cause artifacts in video rendering.

## Overview

Fluvie provides specialized text widgets that integrate with the frame-based animation system:

| Widget | Description | Use Case |
|--------|-------------|----------|
| [FadeText](fade-text.md) | Opacity-aware text | Base text for fading |
| [AnimatedText](animated-text.md) | Text with built-in animations | Animated text entrances |
| [TypewriterText](typewriter-text.md) | Character-by-character reveal | Typewriter effects |
| [CounterText](counter-text.md) | Animated number counting | Statistics, scores |

---

## Quick Examples

### Simple Animated Text

```dart
AnimatedText(
  'Hello World',
  style: TextStyle(fontSize: 72, color: Colors.white),
  animation: PropAnimation.slideUpFade(),
  duration: 30,
)
```

### Typewriter Effect

```dart
TypewriterText(
  'This text types out...',
  style: TextStyle(fontSize: 36),
  startFrame: 30,
  charsPerSecond: 20,
)
```

### Counting Numbers

```dart
CounterText(
  value: 1234,
  startFrame: 30,
  duration: 60,
  style: TextStyle(fontSize: 48),
  formatter: (n) => '\$$n',
)
```

---

## Why FadeText?

Flutter's standard `Opacity` widget uses `saveLayer()` which creates intermediate buffers. These buffers have transparent backgrounds that appear as black rectangles in video frames.

`FadeText` applies opacity directly to the text color, avoiding this issue:

```dart
// Bad: May cause video artifacts
Opacity(
  opacity: 0.5,
  child: Text('Hello'),
)

// Good: Works correctly in video
FadeText(
  'Hello',
  style: TextStyle(color: Colors.white),
)
// Wrap in Fade for opacity control
```

All text widgets in Fluvie use `FadeText` internally.

---

## Common Patterns

### Title with Animation

```dart
VCenter(
  startFrame: 30,
  fadeInFrames: 15,
  child: AnimatedText.slideUpFade(
    'Your 2024',
    style: TextStyle(
      fontSize: 120,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
    duration: 30,
  ),
)
```

### Staggered Text Lines

```dart
VColumn(
  spacing: 20,
  stagger: StaggerConfig.slideUp(delay: 15),
  children: [
    AnimatedText('Line 1', style: titleStyle),
    AnimatedText('Line 2', style: subtitleStyle),
    AnimatedText('Line 3', style: subtitleStyle),
  ],
)
```

### Statistics Display

```dart
VRow(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  stagger: StaggerConfig.fade(delay: 10),
  children: [
    Column(
      children: [
        CounterText(
          value: 2451,
          startFrame: 0,
          duration: 60,
          style: numberStyle,
        ),
        Text('Minutes', style: labelStyle),
      ],
    ),
    Column(
      children: [
        CounterText(
          value: 128,
          startFrame: 10,
          duration: 60,
          style: numberStyle,
        ),
        Text('Songs', style: labelStyle),
      ],
    ),
  ],
)
```

---

## Related

- [Animations](../../animations/README.md) - Animation system
- [PropAnimation](../../animations/prop-animation.md) - Animation classes
- [VColumn](../layout/v-column.md) - Staggered text layouts
