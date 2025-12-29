# PolaroidFrame

> **Classic instant photo style frame**

`PolaroidFrame` wraps content in a polaroid-style frame with a white border, optional caption, shadow, and rotation for a nostalgic photo look.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Constructors](#constructors)
- [Examples](#examples)
- [Related](#related)

---

## Overview

Create instant photo style frames:

```dart
PolaroidFrame(
  size: Size(300, 350),
  caption: 'Summer 2024',
  child: Image.asset('photo.jpg', fit: BoxFit.cover),
)
```

### Visual Structure

```
┌─────────────────────┐
│  ┌───────────────┐  │
│  │               │  │
│  │    Image      │  │
│  │               │  │
│  └───────────────┘  │
│                     │
│    Caption Text     │
└─────────────────────┘
```

---

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `child` | `Widget` | **required** | Content inside the frame |
| `caption` | `String?` | `null` | Caption text below image |
| `size` | `Size` | `Size(300, 350)` | Total frame size |
| `frameColor` | `Color` | off-white | Frame background color |
| `framePadding` | `double` | `12` | Padding around image |
| `bottomPadding` | `double` | `40` | Extra space for caption |
| `shadowBlur` | `double` | `15` | Shadow blur radius |
| `shadowOffset` | `Offset` | `Offset(0, 5)` | Shadow position |
| `shadowColor` | `Color` | black 25% | Shadow color |
| `rotation` | `double` | `0.0` | Rotation in radians |
| `captionStyle` | `TextStyle?` | `null` | Custom caption style |

---

## Constructors

### Default Constructor

Full control over all properties:

```dart
PolaroidFrame(
  child: Image.asset('photo.jpg', fit: BoxFit.cover),
  size: Size(300, 350),
  caption: 'Beach Day',
  frameColor: Color(0xFFFFFFF0),
  framePadding: 12,
  bottomPadding: 40,
  shadowBlur: 15,
  shadowOffset: Offset(0, 5),
  rotation: 0.0,
)
```

### PolaroidFrame.tilted

Creates a frame with a slight random tilt:

```dart
PolaroidFrame.tilted(
  child: Image.asset('photo.jpg', fit: BoxFit.cover),
  caption: 'Summer 2024',
  tiltDegrees: 5,  // Rotation in degrees
)
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `tiltDegrees` | `double` | `5` | Tilt angle in degrees |

---

## Examples

### Basic Polaroid

```dart
PolaroidFrame(
  size: Size(300, 350),
  caption: 'Vacation 2024',
  child: Image.asset(
    'assets/vacation.jpg',
    fit: BoxFit.cover,
  ),
)
```

### Without Caption

```dart
PolaroidFrame(
  size: Size(250, 280),
  bottomPadding: 20,  // Smaller bottom area
  child: Image.asset(
    'assets/photo.jpg',
    fit: BoxFit.cover,
  ),
)
```

### Tilted Polaroid

```dart
PolaroidFrame.tilted(
  tiltDegrees: 8,
  size: Size(300, 350),
  caption: 'Good times',
  child: Image.asset('assets/friends.jpg', fit: BoxFit.cover),
)
```

### Custom Styling

```dart
PolaroidFrame(
  size: Size(350, 400),
  caption: 'Special Memory',
  frameColor: Color(0xFFF5F5DC),  // Beige tint
  framePadding: 16,
  bottomPadding: 50,
  shadowBlur: 20,
  shadowColor: Colors.black.withOpacity(0.3),
  captionStyle: TextStyle(
    fontFamily: 'Caveat',  // Handwritten font
    fontSize: 18,
    color: Color(0xFF333333),
  ),
  child: Image.asset('assets/photo.jpg', fit: BoxFit.cover),
)
```

### Scattered Polaroids

Create a memory wall effect:

```dart
Scene(
  durationInFrames: 180,
  background: Background.solid(Color(0xFF2d3436)),
  children: [
    // First polaroid
    VPositioned(
      left: 100,
      top: 80,
      startFrame: 0,
      fadeInFrames: 20,
      child: PolaroidFrame.tilted(
        tiltDegrees: -5,
        size: Size(280, 320),
        caption: 'Beach Sunset',
        child: Image.asset('assets/beach.jpg', fit: BoxFit.cover),
      ),
    ),

    // Second polaroid
    VPositioned(
      left: 350,
      top: 120,
      startFrame: 15,
      fadeInFrames: 20,
      child: PolaroidFrame.tilted(
        tiltDegrees: 7,
        size: Size(280, 320),
        caption: 'Mountain View',
        child: Image.asset('assets/mountain.jpg', fit: BoxFit.cover),
      ),
    ),

    // Third polaroid
    VPositioned(
      left: 200,
      top: 380,
      startFrame: 30,
      fadeInFrames: 20,
      child: PolaroidFrame.tilted(
        tiltDegrees: -3,
        size: Size(280, 320),
        caption: 'City Night',
        child: Image.asset('assets/city.jpg', fit: BoxFit.cover),
      ),
    ),
  ],
)
```

### With Animation

Combine with animation widgets:

```dart
AnimatedProp(
  animation: PropAnimation.combine([
    PropAnimation.slideUp(distance: 50),
    PropAnimation.fadeIn(),
    PropAnimation.zoomIn(start: 0.9),
  ]),
  duration: 40,
  startFrame: 30,
  curve: Easing.easeOutBack,
  child: PolaroidFrame(
    size: Size(300, 350),
    caption: 'Drop in!',
    child: Image.asset('assets/photo.jpg', fit: BoxFit.cover),
  ),
)
```

### Larger Frame

```dart
PolaroidFrame(
  size: Size(500, 580),
  framePadding: 20,
  bottomPadding: 60,
  caption: 'The Big Picture',
  captionStyle: TextStyle(
    fontSize: 24,
    fontFamily: 'serif',
  ),
  child: Image.asset('assets/hero.jpg', fit: BoxFit.cover),
)
```

### Vintage Look

```dart
PolaroidFrame(
  size: Size(300, 350),
  frameColor: Color(0xFFF5F5DC),  // Aged paper color
  caption: 'Throwback',
  shadowColor: Colors.brown.withOpacity(0.4),
  captionStyle: TextStyle(
    fontFamily: 'Courier',
    fontSize: 14,
    color: Color(0xFF8B4513),  // Sepia text
  ),
  child: ColorFiltered(
    colorFilter: ColorFilter.mode(
      Colors.brown.withOpacity(0.1),
      BlendMode.colorBurn,
    ),
    child: Image.asset('assets/old_photo.jpg', fit: BoxFit.cover),
  ),
)
```

---

## Size Calculations

The image area is calculated from the total size:

```dart
imageWidth = size.width - (framePadding * 2)
imageHeight = size.height - (framePadding * 2) - bottomPadding
```

For a default `Size(300, 350)` with default padding:
- Frame: 300 x 350
- Image area: 276 x 258
- Caption area: 40px tall

---

## Related

- [PhotoCard](photo-card.md) - Modern photo card
- [KenBurnsImage](ken-burns-image.md) - Animated images
- [Collage](../widgets/media/collage.md) - Photo layouts
