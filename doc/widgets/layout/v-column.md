# VColumn

> **Video-aware Column with timing and staggered animations**

`VColumn` extends Flutter's `Column` with video-specific properties including `startFrame`, `endFrame`, fade transitions, and built-in staggered child animations.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Examples](#examples)
- [Stagger Animations](#stagger-animations)
- [Spacing](#spacing)
- [Related](#related)

---

## Overview

`VColumn` is the video-aware version of Flutter's `Column`. It adds timing control and makes it easy to create staggered animations where children animate in sequence:

```dart
VColumn(
  mainAxisAlignment: MainAxisAlignment.center,
  stagger: StaggerConfig.slideUp(delay: 15),
  children: [
    AnimatedText('2024', style: titleStyle),
    AnimatedText('YOUR YEAR', style: subtitleStyle),
    AnimatedText('IN REVIEW', style: subtitleStyle),
  ],
)
```

### When to Use

Use `VColumn` when you need:
- A Column that appears/disappears at specific frames
- Staggered child animations (each child animates in sequence)
- Spacing between children without manual SizedBox widgets
- Combined timing for a group of vertically arranged widgets

---

## Properties

### Column Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `children` | `List<Widget>` | `[]` | Widgets to arrange vertically |
| `mainAxisAlignment` | `MainAxisAlignment` | `start` | Main axis alignment |
| `crossAxisAlignment` | `CrossAxisAlignment` | `center` | Cross axis alignment |
| `mainAxisSize` | `MainAxisSize` | `max` | How much vertical space to use |
| `textDirection` | `TextDirection?` | `null` | Text direction |
| `verticalDirection` | `VerticalDirection` | `down` | Order of children |
| `textBaseline` | `TextBaseline?` | `null` | Baseline for alignment |
| `spacing` | `double` | `0` | Space between children |

### Video Timing Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `startFrame` | `int?` | `null` | Frame to become visible |
| `endFrame` | `int?` | `null` | Frame to become invisible |
| `fadeInFrames` | `int` | `0` | Fade-in duration in frames |
| `fadeOutFrames` | `int` | `0` | Fade-out duration in frames |
| `fadeInCurve` | `Curve` | `easeOut` | Fade-in easing |
| `fadeOutCurve` | `Curve` | `easeIn` | Fade-out easing |

### Stagger Property

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `stagger` | `StaggerConfig?` | `null` | Configuration for staggered animations |

---

## Examples

### Basic Timed Column

```dart
VColumn(
  startFrame: 30,
  endFrame: 150,
  fadeInFrames: 15,
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    Text('Title'),
    Text('Subtitle'),
    Text('Description'),
  ],
)
```

### With Spacing

```dart
VColumn(
  mainAxisAlignment: MainAxisAlignment.center,
  spacing: 20,  // 20 pixels between each child
  children: [
    Card(child: Text('Item 1')),
    Card(child: Text('Item 2')),
    Card(child: Text('Item 3')),
  ],
)
```

### Centered Text Layout

```dart
VColumn(
  mainAxisAlignment: MainAxisAlignment.center,
  crossAxisAlignment: CrossAxisAlignment.center,
  spacing: 10,
  children: [
    Text(
      '2024',
      style: TextStyle(fontSize: 120, fontWeight: FontWeight.bold),
    ),
    Text(
      'YOUR YEAR',
      style: TextStyle(fontSize: 48),
    ),
    Text(
      'IN REVIEW',
      style: TextStyle(fontSize: 48),
    ),
  ],
)
```

---

## Stagger Animations

The most powerful feature of `VColumn` is staggered animations. Each child animates in sequence with a configurable delay:

### Basic Stagger

```dart
VColumn(
  stagger: StaggerConfig(delay: 10, duration: 20),
  children: [
    Text('Line 1'),  // Starts at frame 0
    Text('Line 2'),  // Starts at frame 10
    Text('Line 3'),  // Starts at frame 20
  ],
)
```

### Slide Up Stagger

```dart
VColumn(
  stagger: StaggerConfig.slideUp(
    delay: 15,
    distance: 30,
    curve: Curves.easeOutCubic,
  ),
  children: [
    Text('Slides up 1'),
    Text('Slides up 2'),
    Text('Slides up 3'),
  ],
)
```

### Fade Only Stagger

```dart
VColumn(
  stagger: StaggerConfig.fade(
    delay: 12,
    duration: 25,
    curve: Curves.easeOut,
  ),
  children: [
    Text('Fades in 1'),
    Text('Fades in 2'),
    Text('Fades in 3'),
  ],
)
```

### Scale In Stagger

```dart
VColumn(
  stagger: StaggerConfig.scale(
    delay: 10,
    start: 0.7,  // Start at 70% scale
    curve: Curves.elasticOut,
  ),
  children: [
    Icon(Icons.star),
    Icon(Icons.star),
    Icon(Icons.star),
  ],
)
```

### Combined Effects

```dart
VColumn(
  stagger: StaggerConfig.slideUpScale(
    delay: 15,
    slideDistance: 40,
    scaleStart: 0.8,
    curve: Curves.easeOutBack,
  ),
  children: [
    StatCard(value: 100, label: 'Songs'),
    StatCard(value: 50, label: 'Artists'),
    StatCard(value: 25, label: 'Playlists'),
  ],
)
```

### Stagger Timeline Visualization

```
Frame:    0    10   20   30   40   50   60
          |     |    |    |    |    |    |
Child 0:  ████████████████
Child 1:        ████████████████
Child 2:              ████████████████
          ↑ delay = 10, duration = 20
```

### StaggerConfig Options

| Constructor | Effect |
|------------|--------|
| `StaggerConfig()` | Custom configuration |
| `StaggerConfig.fade()` | Fade in only |
| `StaggerConfig.slideUp()` | Slide up + fade |
| `StaggerConfig.slideDown()` | Slide down + fade |
| `StaggerConfig.slideLeft()` | Slide left + fade |
| `StaggerConfig.slideRight()` | Slide right + fade |
| `StaggerConfig.scale()` | Scale in + fade |
| `StaggerConfig.slideUpScale()` | Slide + scale + fade |

---

## Spacing

Use the `spacing` property instead of manual `SizedBox` widgets:

```dart
// Before: Manual spacing
Column(
  children: [
    Text('Item 1'),
    SizedBox(height: 20),
    Text('Item 2'),
    SizedBox(height: 20),
    Text('Item 3'),
  ],
)

// After: Using spacing
VColumn(
  spacing: 20,
  children: [
    Text('Item 1'),
    Text('Item 2'),
    Text('Item 3'),
  ],
)
```

Spacing works with stagger animations too - the SizedBox spacers are automatically inserted between children.

---

## Complete Example

```dart
Scene(
  durationInFrames: 180,
  background: Background.solid(Colors.black),
  children: [
    VCenter(
      child: VColumn(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 30,
        stagger: StaggerConfig.slideUp(
          delay: 15,
          duration: 25,
          curve: Curves.easeOutCubic,
        ),
        children: [
          Text(
            '2024',
            style: TextStyle(
              fontSize: 120,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            'YOUR YEAR',
            style: TextStyle(
              fontSize: 48,
              color: Colors.white70,
            ),
          ),
          Text(
            'IN REVIEW',
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

---

## Related

- [VRow](v-row.md) - Horizontal equivalent
- [VCenter](v-center.md) - Center with timing
- [StaggerConfig](../../animations/stagger-config.md) - Stagger configuration
- [AnimatedText](../text/animated-text.md) - Animated text widget
