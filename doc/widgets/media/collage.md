# Collage

> **Arrange images in predefined layouts**

`Collage` provides common multi-element layouts for displaying photos, with optional entry animations and stagger effects.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Layouts](#layouts)
- [Examples](#examples)
- [Animations](#animations)
- [Related](#related)

---

## Overview

`Collage` arranges child widgets in predefined layouts:

```dart
Collage.grid2x2(
  spacing: 8,
  children: [
    Image.asset('photo1.jpg'),
    Image.asset('photo2.jpg'),
    Image.asset('photo3.jpg'),
    Image.asset('photo4.jpg'),
  ],
)
```

### Available Layouts

| Layout | Description |
|--------|-------------|
| `grid2x2` | 2x2 grid |
| `grid3x3` | 3x3 grid |
| `splitHorizontal` | Two items side by side |
| `splitVertical` | Two items stacked |
| `featured` | One large + thumbnails |
| `masonry` | Alternating columns |

---

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `children` | `List<Widget>` | **required** | Items to arrange |
| `layout` | `CollageLayout` | **required** | Layout style |
| `spacing` | `double` | `8` | Gap between items |
| `entryAnimation` | `PropAnimation?` | `null` | Item entry animation |
| `staggerDelay` | `int` | `5` | Frames between animations |
| `animationDuration` | `int` | `20` | Animation duration |
| `startFrame` | `int` | `0` | Animation start frame |
| `itemBorderRadius` | `double` | `0` | Item corner radius |

---

## Layouts

### Grid 2x2

```dart
Collage.grid2x2(
  spacing: 8,
  children: [
    Image.asset('photo1.jpg', fit: BoxFit.cover),
    Image.asset('photo2.jpg', fit: BoxFit.cover),
    Image.asset('photo3.jpg', fit: BoxFit.cover),
    Image.asset('photo4.jpg', fit: BoxFit.cover),
  ],
)
```

```
┌───────┬───────┐
│   1   │   2   │
├───────┼───────┤
│   3   │   4   │
└───────┴───────┘
```

### Grid 3x3

```dart
Collage.grid3x3(
  spacing: 4,
  children: List.generate(9, (i) =>
    Image.asset('photo${i+1}.jpg', fit: BoxFit.cover),
  ),
)
```

```
┌─────┬─────┬─────┐
│  1  │  2  │  3  │
├─────┼─────┼─────┤
│  4  │  5  │  6  │
├─────┼─────┼─────┤
│  7  │  8  │  9  │
└─────┴─────┴─────┘
```

### Split Horizontal

```dart
Collage.splitHorizontal(
  spacing: 8,
  left: Image.asset('photo1.jpg', fit: BoxFit.cover),
  right: Image.asset('photo2.jpg', fit: BoxFit.cover),
)
```

```
┌─────────┬─────────┐
│         │         │
│  left   │  right  │
│         │         │
└─────────┴─────────┘
```

### Split Vertical

```dart
Collage.splitVertical(
  spacing: 8,
  top: Image.asset('photo1.jpg', fit: BoxFit.cover),
  bottom: Image.asset('photo2.jpg', fit: BoxFit.cover),
)
```

```
┌─────────────────┐
│      top        │
├─────────────────┤
│     bottom      │
└─────────────────┘
```

### Featured

```dart
Collage.featured(
  spacing: 8,
  main: Image.asset('hero.jpg', fit: BoxFit.cover),
  thumbnails: [
    Image.asset('thumb1.jpg', fit: BoxFit.cover),
    Image.asset('thumb2.jpg', fit: BoxFit.cover),
    Image.asset('thumb3.jpg', fit: BoxFit.cover),
  ],
)
```

```
┌───────────┬─────┐
│           │  1  │
│   main    ├─────┤
│   (2/3)   │  2  │
│           ├─────┤
│           │  3  │
└───────────┴─────┘
```

### Masonry

```dart
Collage(
  layout: CollageLayout.masonry,
  spacing: 8,
  children: [
    Image.asset('photo1.jpg'),
    Image.asset('photo2.jpg'),
    Image.asset('photo3.jpg'),
    Image.asset('photo4.jpg'),
  ],
)
```

```
┌─────┬─────┐
│  1  │  2  │
│     ├─────┤
├─────┤  4  │
│  3  │     │
└─────┴─────┘
```

---

## Examples

### Basic Photo Grid

```dart
Scene(
  durationInFrames: 180,
  background: Background.solid(Colors.black),
  children: [
    VPadding(
      padding: EdgeInsets.all(40),
      startFrame: 30,
      fadeInFrames: 20,
      child: Collage.grid2x2(
        spacing: 12,
        itemBorderRadius: 8,
        children: [
          Image.asset('photos/1.jpg', fit: BoxFit.cover),
          Image.asset('photos/2.jpg', fit: BoxFit.cover),
          Image.asset('photos/3.jpg', fit: BoxFit.cover),
          Image.asset('photos/4.jpg', fit: BoxFit.cover),
        ],
      ),
    ),
  ],
)
```

### With Entry Animation

```dart
Collage.grid2x2(
  spacing: 10,
  entryAnimation: PropAnimation.scaleFade(),
  staggerDelay: 10,
  animationDuration: 25,
  startFrame: 30,
  children: [
    Image.asset('photo1.jpg', fit: BoxFit.cover),
    Image.asset('photo2.jpg', fit: BoxFit.cover),
    Image.asset('photo3.jpg', fit: BoxFit.cover),
    Image.asset('photo4.jpg', fit: BoxFit.cover),
  ],
)
```

Animation timeline:
```
Frame:    30   40   50   60   70   80
          |    |    |    |    |    |
Photo 1:  ███████████████
Photo 2:       ███████████████
Photo 3:            ███████████████
Photo 4:                 ███████████████
```

### Rounded Corners

```dart
Collage.grid3x3(
  spacing: 8,
  itemBorderRadius: 16,  // Rounded corners
  children: photos.map((p) =>
    Image.asset(p, fit: BoxFit.cover),
  ).toList(),
)
```

### Featured With Animation

```dart
Collage.featured(
  spacing: 12,
  itemBorderRadius: 12,
  entryAnimation: PropAnimation.slideUpFade(),
  staggerDelay: 8,
  animationDuration: 30,
  main: Image.asset('hero.jpg', fit: BoxFit.cover),
  thumbnails: [
    Image.asset('thumb1.jpg', fit: BoxFit.cover),
    Image.asset('thumb2.jpg', fit: BoxFit.cover),
    Image.asset('thumb3.jpg', fit: BoxFit.cover),
  ],
)
```

### In a Scene

```dart
Scene(
  durationInFrames: 240,
  background: Background.gradient(
    colors: {
      0: Color(0xFF1a1a2e),
      240: Color(0xFF16213e),
    },
  ),
  children: [
    // Title
    VPositioned(
      left: 0,
      right: 0,
      top: 60,
      startFrame: 0,
      fadeInFrames: 20,
      child: Text(
        'Your Favorite Photos',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ),

    // Photo collage
    VPositioned(
      left: 60,
      right: 60,
      top: 180,
      bottom: 100,
      startFrame: 30,
      fadeInFrames: 25,
      child: Collage.grid2x2(
        spacing: 16,
        itemBorderRadius: 16,
        entryAnimation: PropAnimation.scaleFade(),
        staggerDelay: 12,
        animationDuration: 30,
        startFrame: 30,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset('photo1.jpg', fit: BoxFit.cover),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset('photo2.jpg', fit: BoxFit.cover),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset('photo3.jpg', fit: BoxFit.cover),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset('photo4.jpg', fit: BoxFit.cover),
          ),
        ],
      ),
    ),
  ],
)
```

---

## Animations

### Available Entry Animations

```dart
// Fade in
entryAnimation: const FadeAnimation(start: 0, end: 1)

// Scale up + fade
entryAnimation: PropAnimation.scaleFade()

// Slide up + fade
entryAnimation: PropAnimation.slideUpFade()

// Custom combined
entryAnimation: CombinedAnimation([
  TranslateAnimation(start: Offset(0, 30), end: Offset.zero),
  ScaleAnimation(start: 0.8, end: 1.0),
  FadeAnimation(start: 0, end: 1),
])
```

### Stagger Effect

Each item's animation starts after the previous:

```dart
Collage.grid2x2(
  staggerDelay: 15,       // 15 frames between each item
  animationDuration: 30,  // Each animation lasts 30 frames
  startFrame: 0,          // First item starts at frame 0
  // Item 1: frames 0-30
  // Item 2: frames 15-45
  // Item 3: frames 30-60
  // Item 4: frames 45-75
  children: [...],
)
```

---

## Related

- [PropAnimation](../../animations/prop-animation.md) - Animations
- [PhotoCard](../helpers/photo-card.md) - Styled photo frame
- [PolaroidFrame](../helpers/polaroid-frame.md) - Polaroid style
- [VRow](../layout/v-row.md) - Horizontal layouts
