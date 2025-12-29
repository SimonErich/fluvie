# CounterText

> **Animated number counting widget**

`CounterText` animates a number from a starting value to an ending value, perfect for displaying statistics, scores, or any numeric value that should animate when appearing.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Constructors](#constructors)
- [Examples](#examples)
- [Formatting](#formatting)
- [Related](#related)

---

## Overview

`CounterText` smoothly counts from one number to another:

```dart
CounterText(
  value: 1234,
  startFrame: 30,
  duration: 60,
  style: TextStyle(fontSize: 48, color: Colors.white),
)
```

### When to Use

Use `CounterText` for:
- Statistics displays (minutes, songs, artists)
- Score reveals
- Progress percentages
- Any numeric animation

---

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `value` | `int` | **required** | Target value to count to |
| `startValue` | `int` | `0` | Starting value |
| `startFrame` | `int` | `0` | Frame to start counting |
| `duration` | `int` | `60` | Counting duration in frames |
| `curve` | `Curve` | `easeOut` | Animation easing |
| `style` | `TextStyle?` | `null` | Text styling |
| `formatter` | `String Function(int)?` | `null` | Number formatter |
| `textAlign` | `TextAlign?` | `null` | Text alignment |

---

## Constructors

### Default Constructor

Full control over start and end values:

```dart
CounterText(
  value: 1234,
  startValue: 0,
  startFrame: 30,
  duration: 60,
)
```

### CounterText.countUp

Convenience for counting from zero:

```dart
CounterText.countUp(
  value: 500,
  duration: 45,
)
```

### CounterText.countDown

Count down to zero:

```dart
CounterText.countDown(
  from: 100,  // Counts 100 → 0
  duration: 60,
)
```

### CounterText.percentage

Auto-formats as percentage:

```dart
CounterText.percentage(
  value: 87,  // Displays "87%"
  duration: 45,
)
```

---

## Examples

### Basic Counter

```dart
CounterText(
  value: 2451,
  startFrame: 0,
  duration: 60,
  style: TextStyle(
    fontSize: 72,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  ),
)
```

### Delayed Start

```dart
CounterText(
  value: 128,
  startFrame: 45,  // 1.5 seconds at 30fps
  duration: 45,
  style: TextStyle(fontSize: 48, color: Colors.white),
)
```

### With Formatter

```dart
// Dollar amount
CounterText(
  value: 9999,
  duration: 60,
  formatter: (n) => '\$${n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  )}',  // Formats as $9,999
  style: TextStyle(fontSize: 48, color: Colors.green),
)

// Simple prefix/suffix
CounterText(
  value: 45,
  duration: 45,
  formatter: (n) => '+$n',
  style: TextStyle(fontSize: 36, color: Colors.white),
)
```

### Minutes Counter

```dart
CounterText(
  value: 2451,
  duration: 60,
  formatter: (n) => '${n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  )} min',
  style: TextStyle(fontSize: 48, color: Colors.white),
)
// Displays: 2,451 min
```

### Percentage

```dart
CounterText.percentage(
  value: 92,
  duration: 45,
  style: TextStyle(
    fontSize: 64,
    fontWeight: FontWeight.bold,
    color: Colors.green,
  ),
)
// Displays: 92%
```

### Countdown Timer

```dart
CounterText.countDown(
  from: 10,
  duration: 300,  // 10 seconds at 30fps
  style: TextStyle(
    fontSize: 120,
    fontWeight: FontWeight.bold,
    color: Colors.red,
  ),
)
// Counts 10 → 0 over 10 seconds
```

### Statistics Row

```dart
VRow(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
    Column(
      children: [
        CounterText(
          value: 32,
          startFrame: 20,
          duration: 60,
          style: numberStyle,
        ),
        Text('Artists', style: labelStyle),
      ],
    ),
  ],
)
```

### In StatCard Helper

```dart
// Using the StatCard helper widget
VRow(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  stagger: StaggerConfig.slideUp(delay: 12),
  children: [
    StatCard(value: 2451, label: 'Minutes'),
    StatCard(value: 128, label: 'Songs'),
    StatCard(value: 32, label: 'Artists'),
  ],
)
```

---

## Formatting

### Common Formatters

```dart
// Comma-separated thousands
String formatWithCommas(int n) {
  return n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
}

// Currency
String formatCurrency(int n) => '\$${formatWithCommas(n)}';

// Percentage
String formatPercent(int n) => '$n%';

// Hours and minutes
String formatDuration(int minutes) {
  final hours = minutes ~/ 60;
  final mins = minutes % 60;
  return '${hours}h ${mins}m';
}

// With unit
String formatWithUnit(int n, String unit) => '$n $unit';
```

### Using Formatters

```dart
CounterText(
  value: 150,
  formatter: (n) => formatDuration(n),  // "2h 30m"
  duration: 60,
)

CounterText(
  value: 5000,
  formatter: formatCurrency,  // "$5,000"
  duration: 60,
)
```

---

## Animation Curves

### Different Feels

```dart
// Slow start, fast end (tension)
CounterText(
  value: 100,
  curve: Curves.easeIn,
)

// Fast start, slow end (settle)
CounterText(
  value: 100,
  curve: Curves.easeOut,
)

// Overshoot and settle
CounterText(
  value: 100,
  curve: Curves.easeOutBack,
)

// Linear (constant speed)
CounterText(
  value: 100,
  curve: Curves.linear,
)
```

### Curve Effect on Numbers

With `curve: Curves.easeOut` counting to 100:
- Frame 0: 0
- Frame 15: 70 (fast at start)
- Frame 30: 90
- Frame 45: 98
- Frame 60: 100 (slow at end)

With `curve: Curves.linear`:
- Frame 0: 0
- Frame 15: 25
- Frame 30: 50
- Frame 45: 75
- Frame 60: 100

---

## Timeline

```
value: 100, startFrame: 0, duration: 60

Frame:    0   15   30   45   60   75   90
          |    |    |    |    |    |    |
Value:    0   70   90   98  100  100  100
          ↑ counting ↑  ↑ done

Before startFrame: shows startValue
After animation: shows final value
```

---

## Related

- [AnimatedText](animated-text.md) - Animated text
- [TypewriterText](typewriter-text.md) - Typing effect
- [StatCard](../helpers/stat-card.md) - Statistics display
- [FadeText](fade-text.md) - Base text widget
