# StatCard

> **Animated statistic display with counting effect**

`StatCard` displays numeric values with an animated counting effect, perfect for metrics, scores, or any data that should be revealed dramatically.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Constructors](#constructors)
- [Examples](#examples)
- [Related](#related)

---

## Overview

Display statistics with animated counting:

```dart
StatCard(
  value: 1234,
  label: 'Photos',
  sublabel: 'This Year',
  color: Colors.blue,
  startFrame: 30,
  countDuration: 60,
)
```

The value animates from 0 to the final value over the specified duration.

---

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `value` | `int` | **required** | Target numeric value |
| `label` | `String` | **required** | Main label below value |
| `sublabel` | `String?` | `null` | Secondary label |
| `color` | `Color` | blue | Value text color |
| `startFrame` | `int` | `0` | Frame to start counting |
| `countDuration` | `int` | `60` | Counting animation duration |
| `countCurve` | `Curve` | `easeOut` | Counting easing curve |
| `size` | `Size?` | `null` | Fixed card size |
| `backgroundColor` | `Color?` | `null` | Card background |
| `borderRadius` | `double` | `16` | Corner radius |
| `padding` | `EdgeInsets` | `all(24)` | Internal padding |
| `valueStyle` | `TextStyle?` | `null` | Custom value style |
| `labelStyle` | `TextStyle?` | `null` | Custom label style |
| `sublabelStyle` | `TextStyle?` | `null` | Custom sublabel style |
| `formatter` | `Function?` | `null` | Custom value formatter |

---

## Constructors

### Default Constructor

Basic stat card:

```dart
StatCard(
  value: 1234,
  label: 'Photos',
  sublabel: 'This Year',
  color: Colors.blue,
  startFrame: 30,
  countDuration: 60,
)
```

### StatCard.percentage

Formats value as percentage:

```dart
StatCard.percentage(
  value: 95,
  label: 'Completion',
  sublabel: 'Project Status',
  color: Colors.green,
  startFrame: 30,
)
// Displays: "95%"
```

### StatCard.currency

Formats value as currency:

```dart
StatCard.currency(
  value: 5000,
  label: 'Revenue',
  sublabel: 'Monthly',
  color: Colors.orange,
  currencySymbol: '\$',  // or '€', '£', etc.
  startFrame: 30,
)
// Displays: "$5000"
```

---

## Examples

### Basic Stat

```dart
StatCard(
  value: 2450,
  label: 'Streams',
  color: Color(0xFF1DB954),  // Spotify green
  startFrame: 0,
  countDuration: 45,
)
```

### With Sublabel

```dart
StatCard(
  value: 12,
  label: 'Playlists',
  sublabel: 'Created This Year',
  color: Colors.purple,
  startFrame: 30,
)
```

### Percentage Stat

```dart
StatCard.percentage(
  value: 87,
  label: 'Accuracy',
  sublabel: 'Test Results',
  color: Colors.green,
  startFrame: 0,
  countDuration: 50,
)
```

### Currency Stat

```dart
StatCard.currency(
  value: 15000,
  label: 'Savings',
  sublabel: 'Annual Goal',
  color: Colors.amber,
  currencySymbol: '\$',
  startFrame: 30,
)
```

### Custom Formatter

```dart
StatCard(
  value: 75000,
  label: 'Distance',
  sublabel: 'Total Traveled',
  color: Colors.blue,
  formatter: (n) => '${(n / 1000).toStringAsFixed(1)}k km',
  // Displays: "75.0k km"
)
```

### Stats Dashboard

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
    VPadding(
      padding: EdgeInsets.all(60),
      child: VRow(
        spacing: 40,
        stagger: StaggerConfig.slideUp(delay: 15, duration: 30),
        children: [
          StatCard(
            value: 365,
            label: 'Days',
            sublabel: 'Streak',
            color: Color(0xFF00D4FF),
            startFrame: 30,
            backgroundColor: Color(0xFF2d2d44),
          ),
          StatCard(
            value: 1234,
            label: 'Photos',
            sublabel: 'Captured',
            color: Color(0xFFFF6B6B),
            startFrame: 45,
            backgroundColor: Color(0xFF2d2d44),
          ),
          StatCard(
            value: 89,
            label: 'Countries',
            sublabel: 'Visited',
            color: Color(0xFF4ECDC4),
            startFrame: 60,
            backgroundColor: Color(0xFF2d2d44),
          ),
        ],
      ),
    ),
  ],
)
```

### Custom Styling

```dart
StatCard(
  value: 42,
  label: 'The Answer',
  size: Size(200, 180),
  backgroundColor: Colors.black,
  borderRadius: 24,
  padding: EdgeInsets.all(32),
  valueStyle: TextStyle(
    fontSize: 72,
    fontWeight: FontWeight.w900,
    color: Colors.white,
  ),
  labelStyle: TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: Colors.white70,
  ),
)
```

### Year Review Stats

```dart
Scene(
  durationInFrames: 240,
  children: [
    // Title
    VPositioned(
      left: 0,
      right: 0,
      top: 60,
      startFrame: 0,
      fadeInFrames: 20,
      child: Text(
        'Your 2024 in Numbers',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ),

    // Stats grid
    VPositioned(
      left: 100,
      right: 100,
      top: 160,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StatCard(
                value: 52,
                label: 'Weeks',
                color: Colors.cyan,
                startFrame: 30,
              ),
              SizedBox(width: 40),
              StatCard(
                value: 8760,
                label: 'Hours',
                color: Colors.pink,
                startFrame: 45,
              ),
            ],
          ),
          SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StatCard.percentage(
                value: 100,
                label: 'Commitment',
                color: Colors.green,
                startFrame: 60,
              ),
              SizedBox(width: 40),
              StatCard(
                value: 1,
                label: 'Amazing Year',
                color: Colors.amber,
                startFrame: 75,
              ),
            ],
          ),
        ],
      ),
    ),
  ],
)
```

### Slow Dramatic Count

```dart
StatCard(
  value: 1000000,
  label: 'Milestone',
  sublabel: 'One Million!',
  color: Colors.gold,
  startFrame: 0,
  countDuration: 120,  // 4 seconds at 30fps
  countCurve: Curves.easeOutCubic,
  formatter: (n) => n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  ),
  // Displays: "1,000,000"
)
```

---

## Animation Timeline

```
Frame:    0       30      60      90
          |        |       |       |
Value:    0 ─────> ... ───> 1234 ──> 1234
          ↑        ↑              ↑
      startFrame  counting     complete
```

With `countCurve: Curves.easeOut`, the counting is fast at first and slows toward the end.

---

## Related

- [CounterText](../widgets/text/counter-text.md) - Counting text widget
- [TimeConsumer](../widgets/core/time-consumer.md) - Frame-based state
- [StaggerConfig](../animations/stagger-config.md) - Staggered animations
