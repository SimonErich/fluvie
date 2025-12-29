# FadeText

> **Opacity-aware text widget for video rendering**

`FadeText` is a text widget that applies opacity from ancestor `Fade` widgets directly to the text color, avoiding the `saveLayer()` artifacts that Flutter's `Opacity` widget causes in video rendering.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Examples](#examples)
- [Why Use FadeText](#why-use-fadetext)
- [Related](#related)

---

## Overview

`FadeText` works like Flutter's `Text` but responds to ancestor `Fade` widgets by modifying the text color's alpha channel:

```dart
Fade(
  opacity: 0.5,
  child: FadeText(
    'Hello World',
    style: TextStyle(color: Colors.white, fontSize: 24),
  ),
)
```

### When to Use

Use `FadeText` when:
- Text needs to fade in/out within video rendering
- You're building custom widgets that need fade support
- Using `Layer` or other fade-aware containers

Use `AnimatedText` instead for common animated text patterns with built-in timing.

---

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `String` | **required** | Text to display |
| `style` | `TextStyle?` | `null` | Text styling |
| `textAlign` | `TextAlign?` | `null` | Horizontal alignment |
| `textDirection` | `TextDirection?` | `null` | Text direction |
| `softWrap` | `bool?` | `null` | Line break behavior |
| `overflow` | `TextOverflow?` | `null` | Overflow handling |
| `maxLines` | `int?` | `null` | Maximum line count |
| `semanticsLabel` | `String?` | `null` | Accessibility label |
| `textWidthBasis` | `TextWidthBasis?` | `null` | Width calculation |
| `textHeightBehavior` | `TextHeightBehavior?` | `null` | Height behavior |

---

## Examples

### Basic Usage

```dart
FadeText(
  'Hello World',
  style: TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  ),
)
```

### With Fade Container

```dart
Fade(
  opacity: 0.7,
  child: FadeText(
    'Partially transparent',
    style: TextStyle(color: Colors.white, fontSize: 24),
  ),
)
```

### In a Layer

```dart
Layer(
  startFrame: 30,
  endFrame: 120,
  fadeInFrames: 15,
  fadeOutFrames: 15,
  child: Center(
    child: FadeText(
      'This fades in and out',
      style: TextStyle(fontSize: 36, color: Colors.white),
    ),
  ),
)
```

### Multiple Lines

```dart
FadeText(
  'This is a longer text\nthat spans multiple lines\nand handles wrapping correctly.',
  style: TextStyle(
    fontSize: 18,
    color: Colors.white,
    height: 1.5,
  ),
  textAlign: TextAlign.center,
  maxLines: 3,
  overflow: TextOverflow.ellipsis,
)
```

### Styled Text

```dart
FadeText(
  'Styled Text',
  style: TextStyle(
    fontSize: 64,
    fontWeight: FontWeight.w900,
    color: Colors.white,
    letterSpacing: 4,
    shadows: [
      Shadow(
        offset: Offset(2, 2),
        blurRadius: 4,
        color: Colors.black54,
      ),
    ],
  ),
)
```

---

## Why Use FadeText

### The Problem with Opacity

Flutter's `Opacity` widget uses `saveLayer()` internally:

```dart
// This creates a transparent buffer
Opacity(
  opacity: 0.5,
  child: Text('Hello'),
)
```

When rendering to video frames, the transparent buffer appears as a black rectangle.

### The Solution

`FadeText` applies opacity directly to the text color:

```dart
// Original color: rgba(255, 255, 255, 1.0) (white)
// Fade opacity: 0.5
// Result color: rgba(255, 255, 255, 0.5) (50% white)
```

No intermediate buffer is created, so no artifacts appear.

### How It Works

1. `FadeText` reads the fade opacity from ancestor `Fade` widgets using `FadeValue.of(context)`
2. It multiplies the text color's alpha by the fade opacity
3. Renders the text with the adjusted color

```dart
// Internal logic (simplified)
final fadeOpacity = FadeValue.of(context);
final baseColor = style.color ?? Colors.white;
final fadedColor = baseColor.withOpacity(baseColor.opacity * fadeOpacity);
```

### Opacity Stacking

Opacity values stack multiplicatively:

```dart
Fade(
  opacity: 0.8,
  child: Fade(
    opacity: 0.5,
    child: FadeText(
      'Stacked opacity',
      style: TextStyle(color: Colors.white),
    ),
  ),
)
// Result: 0.8 * 0.5 = 0.4 opacity
```

---

## Custom Fade-Aware Widgets

When building custom widgets that contain text and need fade support:

```dart
class FadeAwareCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const FadeAwareCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    // FadeText automatically picks up Fade from ancestors
    return FadeContainer(
      child: Column(
        children: [
          FadeText(title, style: titleStyle),
          FadeText(subtitle, style: subtitleStyle),
        ],
      ),
    );
  }
}
```

---

## Related

- [AnimatedText](animated-text.md) - Text with animations
- [Fade](../core/fade.md) - Fade opacity provider
- [Layer](../layout/layer.md) - Layer with fade support
