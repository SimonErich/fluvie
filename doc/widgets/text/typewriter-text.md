# TypewriterText

> **Character-by-character text reveal with cursor**

`TypewriterText` animates text by revealing characters one at a time, like a typewriter. It includes an optional blinking cursor for a realistic effect.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Examples](#examples)
- [Timing Calculation](#timing-calculation)
- [Related](#related)

---

## Overview

`TypewriterText` progressively reveals text based on the current frame:

```dart
TypewriterText(
  'Hello World',
  style: TextStyle(fontSize: 24, color: Colors.white),
  startFrame: 30,
  charsPerSecond: 20,
)
```

### When to Use

Use `TypewriterText` for:
- Typing effects in intro sequences
- Code or terminal displays
- Story narration
- Any text that should "type out"

---

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `text` | `String` | **required** | Text to reveal |
| `style` | `TextStyle?` | `null` | Text styling |
| `startFrame` | `int` | `0` | Frame to start typing |
| `charsPerSecond` | `double` | `15` | Typing speed |
| `showCursor` | `bool` | `true` | Show blinking cursor |
| `cursorChar` | `String` | `'|'` | Cursor character |
| `cursorBlinkFrames` | `int` | `15` | Cursor blink speed |
| `textAlign` | `TextAlign?` | `null` | Text alignment |
| `maxLines` | `int?` | `null` | Maximum lines |
| `overflow` | `TextOverflow?` | `null` | Overflow handling |

---

## Examples

### Basic Typewriter

```dart
TypewriterText(
  'Welcome to the show...',
  style: TextStyle(
    fontSize: 36,
    color: Colors.white,
    fontFamily: 'monospace',
  ),
  charsPerSecond: 15,
)
```

### Without Cursor

```dart
TypewriterText(
  'Clean typing effect',
  showCursor: false,
  charsPerSecond: 20,
  style: TextStyle(fontSize: 24, color: Colors.white),
)
```

### Custom Cursor

```dart
TypewriterText(
  'Custom cursor',
  cursorChar: '▌',        // Block cursor
  cursorBlinkFrames: 10,  // Faster blink
  style: TextStyle(
    fontSize: 24,
    color: Colors.green,
    fontFamily: 'Courier',
  ),
)
```

### Delayed Start

```dart
TypewriterText(
  'This starts after 2 seconds',
  startFrame: 60,  // 2 seconds at 30fps
  charsPerSecond: 18,
  style: TextStyle(fontSize: 24, color: Colors.white),
)
```

### Slow Typing

```dart
TypewriterText(
  'Slow and dramatic...',
  charsPerSecond: 8,  // Very slow
  style: TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  ),
)
```

### Fast Typing

```dart
TypewriterText(
  'Quick typing like a pro!',
  charsPerSecond: 40,  // Very fast
  style: TextStyle(fontSize: 24, color: Colors.green),
)
```

### Multi-line Text

```dart
TypewriterText(
  'Line one...\nLine two...\nLine three...',
  charsPerSecond: 15,
  style: TextStyle(
    fontSize: 20,
    color: Colors.white,
    height: 1.5,
  ),
)
```

### In a Scene

```dart
Scene(
  durationInFrames: 180,
  background: Background.solid(Colors.black),
  children: [
    VPositioned(
      left: 100,
      right: 100,
      top: 200,
      child: TypewriterText(
        'Welcome to your personalized recap...',
        startFrame: 30,
        charsPerSecond: 20,
        style: TextStyle(
          fontSize: 32,
          color: Colors.white,
          fontFamily: 'Courier New',
        ),
      ),
    ),
  ],
)
```

### Code Display

```dart
TypewriterText(
  '''
void main() {
  print('Hello, World!');
}
''',
  charsPerSecond: 25,
  cursorChar: '_',
  style: TextStyle(
    fontSize: 18,
    color: Color(0xFF00FF00),
    fontFamily: 'monospace',
  ),
)
```

---

## Timing Calculation

### Characters Per Frame

The typing speed is calculated from `charsPerSecond` and the video's FPS:

```dart
// At 30fps with charsPerSecond: 15
// charsPerFrame = 15 / 30 = 0.5
// One character every 2 frames
```

### Total Duration

Use `totalDuration(fps)` to calculate how long the typing takes:

```dart
final typewriter = TypewriterText(
  'Hello World',  // 11 characters
  charsPerSecond: 15,
);

final duration = typewriter.totalDuration(30);
// At 30fps: 11 / (15/30) = 22 frames
```

### Timeline Example

```
Text: "Hello"
charsPerSecond: 15, fps: 30
charsPerFrame: 0.5

Frame:    0    2    4    6    8   10
          |    |    |    |    |    |
Display:  |    H|   He|  Hel| Hell|Hello|

(Cursor blinks every 15 frames)
```

---

## Cursor Behavior

### During Typing

The cursor appears at the end of the visible text and blinks:

```
Frame 0:  |
Frame 5:  Hel|
Frame 10: Hello|
Frame 15: Hello (cursor hidden)
Frame 30: Hello|
```

### After Typing Complete

Once all text is revealed, the cursor continues blinking:

```
Frame 20: Hello| (typing complete)
Frame 30: Hello  (blink off)
Frame 45: Hello| (blink on)
```

### Cursor Characters

| Character | Style |
|-----------|-------|
| `'|'` | Standard pipe (default) |
| `'_'` | Underscore |
| `'▌'` | Block cursor |
| `'█'` | Full block |
| `'▊'` | Thick block |

---

## Performance Tips

### Long Text

For very long text, consider breaking into multiple `TypewriterText` widgets:

```dart
VColumn(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    TypewriterText(
      'First paragraph...',
      startFrame: 0,
    ),
    TypewriterText(
      'Second paragraph...',
      startFrame: 90,  // After first finishes
    ),
  ],
)
```

### Calculate Scene Length

```dart
// Ensure scene is long enough for typing
final text = 'Your long message here...';
final typingDuration = (text.length / charsPerSecond * fps).ceil();
final sceneLength = startFrame + typingDuration + 30; // Plus some buffer
```

---

## Related

- [AnimatedText](animated-text.md) - Animation-based text
- [CounterText](counter-text.md) - Number counting
- [FadeText](fade-text.md) - Base text widget
- [TimeConsumer](../core/time-consumer.md) - Frame-based logic
