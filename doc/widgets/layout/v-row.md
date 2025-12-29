# VRow

> **Video-aware Row with timing and staggered animations**

`VRow` extends Flutter's `Row` with video-specific properties including `startFrame`, `endFrame`, fade transitions, and built-in staggered child animations.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Examples](#examples)
- [Stagger Animations](#stagger-animations)
- [Related](#related)

---

## Overview

`VRow` is the video-aware version of Flutter's `Row`. Like `VColumn`, it adds timing control and staggered animations where children animate in sequence:

```dart
VRow(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  stagger: StaggerConfig.slideUp(delay: 10),
  children: [
    StatCard(value: 42, label: 'Songs'),
    StatCard(value: 15, label: 'Artists'),
    StatCard(value: 8, label: 'Playlists'),
  ],
)
```

### When to Use

Use `VRow` when you need:
- A Row that appears/disappears at specific frames
- Staggered child animations horizontally
- Spacing between children
- Combined timing for horizontally arranged widgets

---

## Properties

### Row Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `children` | `List<Widget>` | `[]` | Widgets to arrange horizontally |
| `mainAxisAlignment` | `MainAxisAlignment` | `start` | Main axis alignment |
| `crossAxisAlignment` | `CrossAxisAlignment` | `center` | Cross axis alignment |
| `mainAxisSize` | `MainAxisSize` | `max` | How much horizontal space to use |
| `textDirection` | `TextDirection?` | `null` | Text direction |
| `verticalDirection` | `VerticalDirection` | `down` | Vertical direction for cross axis |
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

### Basic Row

```dart
VRow(
  mainAxisAlignment: MainAxisAlignment.center,
  spacing: 20,
  children: [
    Icon(Icons.star, size: 48),
    Icon(Icons.star, size: 48),
    Icon(Icons.star, size: 48),
  ],
)
```

### Timed Row

```dart
VRow(
  startFrame: 30,
  endFrame: 120,
  fadeInFrames: 15,
  fadeOutFrames: 15,
  mainAxisAlignment: MainAxisAlignment.spaceAround,
  children: [
    Text('Left'),
    Text('Center'),
    Text('Right'),
  ],
)
```

### Evenly Spaced Stats

```dart
VRow(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  children: [
    Column(
      children: [
        Text('100', style: numberStyle),
        Text('Songs'),
      ],
    ),
    Column(
      children: [
        Text('25', style: numberStyle),
        Text('Artists'),
      ],
    ),
    Column(
      children: [
        Text('10', style: numberStyle),
        Text('Hours'),
      ],
    ),
  ],
)
```

---

## Stagger Animations

`VRow` supports the same stagger animations as `VColumn`:

### Slide In From Left

```dart
VRow(
  mainAxisAlignment: MainAxisAlignment.center,
  spacing: 30,
  stagger: StaggerConfig.slideLeft(
    delay: 12,
    distance: 40,
    curve: Curves.easeOutCubic,
  ),
  children: [
    StatCard(value: 42, label: 'Songs'),
    StatCard(value: 15, label: 'Artists'),
    StatCard(value: 8, label: 'Playlists'),
  ],
)
```

### Scale In

```dart
VRow(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  stagger: StaggerConfig.scale(
    delay: 10,
    start: 0.5,
    curve: Curves.elasticOut,
  ),
  children: [
    CircleAvatar(backgroundImage: NetworkImage(url1)),
    CircleAvatar(backgroundImage: NetworkImage(url2)),
    CircleAvatar(backgroundImage: NetworkImage(url3)),
  ],
)
```

### Slide Up (Common for Bottom Stats)

```dart
VRow(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  stagger: StaggerConfig.slideUp(
    delay: 15,
    distance: 30,
    curve: Curves.easeOutBack,
  ),
  children: [
    MetricCard(icon: Icons.music_note, value: '1,234'),
    MetricCard(icon: Icons.timer, value: '48h'),
    MetricCard(icon: Icons.favorite, value: '567'),
  ],
)
```

### Timeline Visualization

```
Frame:    0    12   24   36   48   60
          |     |    |    |    |    |
Child 0:  ████████████████
Child 1:        ████████████████
Child 2:              ████████████████
          ↑ delay = 12, duration = 20
```

---

## Common Patterns

### Stats Row at Bottom

```dart
VPositioned(
  left: 0,
  right: 0,
  bottom: 100,
  startFrame: 30,
  fadeInFrames: 20,
  child: VRow(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    stagger: StaggerConfig.slideUp(delay: 10),
    children: [
      StatColumn(value: '2,451', label: 'Minutes Played'),
      StatColumn(value: '128', label: 'Songs'),
      StatColumn(value: '32', label: 'Artists'),
    ],
  ),
)
```

### Icon Bar

```dart
VRow(
  mainAxisAlignment: MainAxisAlignment.center,
  spacing: 40,
  stagger: StaggerConfig.fade(delay: 8),
  children: [
    IconButton(icon: Icons.skip_previous),
    IconButton(icon: Icons.play_arrow),
    IconButton(icon: Icons.skip_next),
  ],
)
```

### Photo Strip

```dart
VRow(
  mainAxisAlignment: MainAxisAlignment.center,
  spacing: 20,
  stagger: StaggerConfig.scale(delay: 15, start: 0.8),
  children: [
    PhotoCard(image: 'photo1.jpg', rotation: -5),
    PhotoCard(image: 'photo2.jpg', rotation: 3),
    PhotoCard(image: 'photo3.jpg', rotation: -2),
    PhotoCard(image: 'photo4.jpg', rotation: 4),
  ],
)
```

---

## Complete Example

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
    // Stats row at bottom
    VPositioned(
      left: 50,
      right: 50,
      bottom: 150,
      startFrame: 45,
      fadeInFrames: 20,
      child: VRow(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        stagger: StaggerConfig.slideUp(
          delay: 12,
          distance: 40,
          curve: Curves.easeOutCubic,
        ),
        children: [
          _StatWidget(
            value: '2,451',
            label: 'Minutes',
            icon: Icons.timer,
          ),
          _StatWidget(
            value: '128',
            label: 'Songs',
            icon: Icons.music_note,
          ),
          _StatWidget(
            value: '32',
            label: 'Artists',
            icon: Icons.person,
          ),
        ],
      ),
    ),
  ],
)
```

---

## Related

- [VColumn](v-column.md) - Vertical equivalent
- [VCenter](v-center.md) - Center with timing
- [StaggerConfig](../../animations/stagger-config.md) - Stagger configuration
- [StatCard](../helpers/stat-card.md) - Statistics display widget
