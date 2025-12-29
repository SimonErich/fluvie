# StaggerConfig

> **Configuration for staggered child animations**

`StaggerConfig` defines how children in `VColumn` and `VRow` should animate in sequence, with configurable delays between each child's animation start.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Factory Constructors](#factory-constructors)
- [Helper Methods](#helper-methods)
- [Examples](#examples)
- [Related](#related)

---

## Overview

Stagger animations create a cascading reveal effect where each child starts animating after a delay:

```dart
VColumn(
  stagger: StaggerConfig(
    delay: 10,
    duration: 30,
  ),
  children: [
    Text('Item 1'),  // Starts at frame 0
    Text('Item 2'),  // Starts at frame 10
    Text('Item 3'),  // Starts at frame 20
    Text('Item 4'),  // Starts at frame 30
  ],
)
```

### Animation Timeline

```
Frame:    0   10   20   30   40   50   60   70
          |    |    |    |    |    |    |    |
Item 1:   ███████████████████████████████
Item 2:        ███████████████████████████████
Item 3:             ███████████████████████████████
Item 4:                  ███████████████████████████████
          ↑    ↑    ↑    ↑
       delay between each start
```

---

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `delay` | `int` | **required** | Frames between each child's start |
| `duration` | `int?` | `null` | Animation duration (default: 20) |
| `curve` | `Curve` | `Curves.easeOut` | Easing curve |
| `fadeIn` | `bool` | `true` | Enable fade animation |
| `slideIn` | `bool` | `false` | Enable slide animation |
| `slideOffset` | `Offset` | `Offset(0, 30)` | Slide start offset |
| `scaleIn` | `bool` | `false` | Enable scale animation |
| `scaleStart` | `double` | `0.8` | Starting scale value |

---

## Factory Constructors

### Basic Constructor

Full control over all properties:

```dart
StaggerConfig(
  delay: 10,
  duration: 30,
  curve: Curves.easeOut,
  fadeIn: true,
  slideIn: true,
  slideOffset: Offset(0, 40),
  scaleIn: false,
  scaleStart: 0.8,
)
```

### StaggerConfig.fade

Simple fade-in only:

```dart
StaggerConfig.fade(
  delay: 10,
  duration: 25,
  curve: Curves.easeOut,
)
```

### StaggerConfig.slideUp

Slide up from below with fade:

```dart
StaggerConfig.slideUp(
  delay: 10,
  duration: 30,
  distance: 40,  // Pixels to slide
  curve: Curves.easeOut,
)
```

### StaggerConfig.slideDown

Slide down from above with fade:

```dart
StaggerConfig.slideDown(
  delay: 10,
  duration: 30,
  distance: 40,
  curve: Curves.easeOut,
)
```

### StaggerConfig.slideLeft

Slide from the right with fade:

```dart
StaggerConfig.slideLeft(
  delay: 10,
  duration: 30,
  distance: 50,
  curve: Curves.easeOut,
)
```

### StaggerConfig.slideRight

Slide from the left with fade:

```dart
StaggerConfig.slideRight(
  delay: 10,
  duration: 30,
  distance: 50,
  curve: Curves.easeOut,
)
```

### StaggerConfig.scale

Scale up with fade:

```dart
StaggerConfig.scale(
  delay: 10,
  duration: 30,
  start: 0.7,  // Starting scale
  curve: Curves.easeOut,
)
```

### StaggerConfig.slideUpScale

Combined slide up + scale + fade:

```dart
StaggerConfig.slideUpScale(
  delay: 12,
  duration: 35,
  slideDistance: 30,
  scaleStart: 0.85,
  curve: Curves.easeOut,
)
```

---

## Helper Methods

### effectiveDuration

Returns the actual duration (default 20 if not specified):

```dart
final stagger = StaggerConfig(delay: 10);
print(stagger.effectiveDuration);  // 20
```

### startFrameForIndex

Calculates when a specific child starts:

```dart
final stagger = StaggerConfig(delay: 10);
print(stagger.startFrameForIndex(0));  // 0
print(stagger.startFrameForIndex(1));  // 10
print(stagger.startFrameForIndex(2));  // 20

// With base frame offset
print(stagger.startFrameForIndex(0, 30));  // 30
print(stagger.startFrameForIndex(1, 30));  // 40
```

### endFrameForIndex

Calculates when a specific child's animation ends:

```dart
final stagger = StaggerConfig(delay: 10, duration: 25);
print(stagger.endFrameForIndex(0));  // 25
print(stagger.endFrameForIndex(1));  // 35
print(stagger.endFrameForIndex(2));  // 45
```

### totalDuration

Calculates the total time for all children to finish:

```dart
final stagger = StaggerConfig(delay: 10, duration: 30);

// 3 children: last starts at frame 20, ends at frame 50
print(stagger.totalDuration(3));  // 50

// 5 children: last starts at frame 40, ends at frame 70
print(stagger.totalDuration(5));  // 70
```

---

## Examples

### Basic Staggered List

```dart
Scene(
  durationInFrames: 150,
  background: Background.solid(Colors.black),
  children: [
    VPadding(
      padding: EdgeInsets.all(60),
      startFrame: 0,
      child: VColumn(
        spacing: 20,
        stagger: StaggerConfig.slideUp(
          delay: 10,
          duration: 30,
          distance: 40,
        ),
        children: [
          Text('First item', style: TextStyle(fontSize: 24, color: Colors.white)),
          Text('Second item', style: TextStyle(fontSize: 24, color: Colors.white)),
          Text('Third item', style: TextStyle(fontSize: 24, color: Colors.white)),
          Text('Fourth item', style: TextStyle(fontSize: 24, color: Colors.white)),
        ],
      ),
    ),
  ],
)
```

### Staggered Row

```dart
VRow(
  spacing: 20,
  stagger: StaggerConfig.scale(
    delay: 8,
    duration: 25,
    start: 0.5,
  ),
  children: [
    Icon(Icons.star, size: 48, color: Colors.yellow),
    Icon(Icons.star, size: 48, color: Colors.yellow),
    Icon(Icons.star, size: 48, color: Colors.yellow),
    Icon(Icons.star, size: 48, color: Colors.yellow),
    Icon(Icons.star, size: 48, color: Colors.yellow),
  ],
)
```

### Ranking List

```dart
VColumn(
  spacing: 16,
  stagger: StaggerConfig.slideRight(
    delay: 12,
    duration: 30,
    distance: 100,
  ),
  children: [
    _buildRankItem(1, 'Pop Hits', '2,450 streams'),
    _buildRankItem(2, 'Rock Classics', '1,890 streams'),
    _buildRankItem(3, 'Jazz Vibes', '1,234 streams'),
    _buildRankItem(4, 'Electronic', '987 streams'),
    _buildRankItem(5, 'Classical', '654 streams'),
  ],
)
```

### Grid with Stagger

```dart
Column(
  children: [
    // First row
    VRow(
      stagger: StaggerConfig.scale(delay: 5, duration: 20),
      children: [card1, card2, card3],
    ),
    SizedBox(height: 20),
    // Second row (starts after first row)
    VRow(
      stagger: StaggerConfig.scale(
        delay: 5,
        duration: 20,
      ).copyWith(startFrame: 30),  // Offset start
      children: [card4, card5, card6],
    ),
  ],
)
```

### Fast Reveal

Quick succession for dynamic feel:

```dart
VColumn(
  stagger: StaggerConfig.fade(
    delay: 3,      // Very short delay
    duration: 15,  // Quick animation
  ),
  children: statsWidgets,
)
```

### Slow Dramatic Reveal

Slower pacing for emphasis:

```dart
VColumn(
  stagger: StaggerConfig.slideUpScale(
    delay: 25,     // Long delay between items
    duration: 45,  // Slow animation
    slideDistance: 60,
    scaleStart: 0.6,
  ),
  children: importantItems,
)
```

### Custom Combined Effect

```dart
VColumn(
  stagger: StaggerConfig(
    delay: 15,
    duration: 35,
    curve: Easing.easeOutBack,  // Bounce effect
    fadeIn: true,
    slideIn: true,
    slideOffset: Offset(0, 50),
    scaleIn: true,
    scaleStart: 0.7,
  ),
  children: featureCards,
)
```

### Calculating Scene Length

Use `totalDuration` to size your scene:

```dart
final items = ['Item 1', 'Item 2', 'Item 3', 'Item 4', 'Item 5'];
final stagger = StaggerConfig.slideUp(delay: 15, duration: 30);

// Calculate minimum scene length
final animationLength = stagger.totalDuration(items.length);
final holdTime = 60;  // Time to hold after animations complete
final sceneLength = animationLength + holdTime;

Scene(
  durationInFrames: sceneLength,  // 90 + 60 = 150 frames
  children: [
    VColumn(
      stagger: stagger,
      children: items.map((item) => Text(item)).toList(),
    ),
  ],
)
```

### Different Curves

```dart
// Snappy entrance
StaggerConfig.slideUp(
  delay: 8,
  curve: Easing.easeOutExpo,
)

// Bouncy entrance
StaggerConfig.scale(
  delay: 10,
  curve: Easing.easeOutBack,
)

// Smooth entrance
StaggerConfig.fade(
  delay: 12,
  curve: Easing.easeInOutCubic,
)
```

---

## Timing Visualization

For a stagger with `delay: 10` and `duration: 30`:

```
Child    Start    End      Timeline
─────    ─────    ───      ────────────────────────────────────
  0        0       30      ████████████████████████████████
  1       10       40           ████████████████████████████████
  2       20       50                ████████████████████████████████
  3       30       60                     ████████████████████████████████
  4       40       70                          ████████████████████████████████

Frame:   0   10   20   30   40   50   60   70
```

Total duration = `startFrame(4) + duration` = `40 + 30` = `70 frames`

---

## Related

- [VColumn](../widgets/layout/v-column.md) - Vertical layout with stagger
- [VRow](../widgets/layout/v-row.md) - Horizontal layout with stagger
- [PropAnimation](prop-animation.md) - Animation base class
- [Easing](easing.md) - Animation curves
