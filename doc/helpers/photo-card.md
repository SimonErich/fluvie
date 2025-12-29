# PhotoCard

> **Modern photo card with shadow, rounded corners, and optional effects**

`PhotoCard` provides a clean, professional way to display photos with optional Ken Burns effect, rotation, caption, and shadow.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Constructors](#constructors)
- [AnimatedPhotoCard](#animatedphotocard)
- [Examples](#examples)
- [Related](#related)

---

## Overview

Display photos with modern styling:

```dart
PhotoCard(
  assetPath: 'assets/photo.jpg',
  width: 400,
  height: 300,
  borderRadius: 12,
  elevation: 15,
)
```

---

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `assetPath` | `String` | **required** | Path to image asset |
| `width` | `double` | **required** | Card width |
| `height` | `double` | **required** | Card height |
| `rotation` | `double` | `0` | Rotation in radians |
| `elevation` | `double` | `15` | Shadow depth |
| `borderRadius` | `double` | `12` | Corner radius |
| `kenBurns` | `bool` | `false` | Enable Ken Burns effect |
| `kenBurnsStartScale` | `double` | `1.0` | Ken Burns start scale |
| `kenBurnsEndScale` | `double` | `1.15` | Ken Burns end scale |
| `kenBurnsStartAlignment` | `Alignment` | `center` | Ken Burns start focus |
| `kenBurnsEndAlignment` | `Alignment` | `center` | Ken Burns end focus |
| `borderColor` | `Color?` | `null` | Optional border color |
| `borderWidth` | `double` | `3` | Border width |
| `backgroundColor` | `Color` | `white` | Background color |
| `fit` | `BoxFit` | `cover` | Image fit mode |
| `caption` | `String?` | `null` | Caption text |
| `captionStyle` | `TextStyle?` | `null` | Caption style |
| `errorBuilder` | `Function?` | `null` | Error widget builder |

---

## Constructors

### Default Constructor

Full control:

```dart
PhotoCard(
  assetPath: 'assets/photo.jpg',
  width: 400,
  height: 300,
  rotation: -0.05,
  elevation: 20,
  borderRadius: 16,
  kenBurns: true,
  kenBurnsEndScale: 1.2,
)
```

### PhotoCard.withKenBurns

Preset for zoom effect:

```dart
PhotoCard.withKenBurns(
  assetPath: 'assets/photo.jpg',
  width: 400,
  height: 300,
  zoomAmount: 0.15,      // How much to zoom (0.15 = 15%)
  focus: Alignment.center,  // Where to focus the zoom
)
```

### PhotoCard.withPan

Preset for pan effect (no zoom):

```dart
PhotoCard.withPan(
  assetPath: 'assets/photo.jpg',
  width: 400,
  height: 300,
  from: Alignment.centerLeft,   // Start position
  to: Alignment.centerRight,    // End position
  scale: 1.2,                   // Scale to enable panning
)
```

### PhotoCard.simple

Basic photo card without effects:

```dart
PhotoCard.simple(
  assetPath: 'assets/photo.jpg',
  width: 400,
  height: 300,
  borderRadius: 12,
  elevation: 10,
)
```

---

## AnimatedPhotoCard

Photo card with entry animation:

```dart
AnimatedPhotoCard(
  assetPath: 'assets/photo.jpg',
  width: 400,
  height: 300,
  startFrame: 30,
  animationDuration: 25,
  slideFrom: SlideFromDirection.bottom,
  slideDistance: 80,
)
```

### AnimatedPhotoCard Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `startFrame` | `int` | `0` | Animation start frame |
| `animationDuration` | `int` | `30` | Animation duration |
| `slideFrom` | `SlideFromDirection` | `bottom` | Entry direction |
| `slideDistance` | `double` | `80` | Slide distance |
| `curve` | `Curve` | `easeOutCubic` | Animation curve |
| `kenBurns` | `bool` | `true` | Enable Ken Burns |

### Slide Directions

- `SlideFromDirection.left`
- `SlideFromDirection.right`
- `SlideFromDirection.top`
- `SlideFromDirection.bottom`

---

## Examples

### Basic Photo Card

```dart
PhotoCard.simple(
  assetPath: 'assets/vacation.jpg',
  width: 400,
  height: 300,
)
```

### With Ken Burns Zoom

```dart
PhotoCard.withKenBurns(
  assetPath: 'assets/landscape.jpg',
  width: 500,
  height: 350,
  zoomAmount: 0.2,
  focus: Alignment.center,
)
```

### With Pan Effect

```dart
PhotoCard.withPan(
  assetPath: 'assets/panorama.jpg',
  width: 600,
  height: 300,
  from: Alignment.centerLeft,
  to: Alignment.centerRight,
  scale: 1.3,
)
```

### Tilted Photo

```dart
PhotoCard(
  assetPath: 'assets/photo.jpg',
  width: 400,
  height: 300,
  rotation: -0.05,  // Slight left tilt
  elevation: 20,
  borderRadius: 16,
  kenBurns: true,
)
```

### With Caption

```dart
PhotoCard(
  assetPath: 'assets/photo.jpg',
  width: 400,
  height: 340,  // Extra height for caption
  caption: 'Beach Sunset',
  captionStyle: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: Colors.black87,
  ),
)
```

### With Border

```dart
PhotoCard(
  assetPath: 'assets/photo.jpg',
  width: 400,
  height: 300,
  borderColor: Colors.white,
  borderWidth: 4,
  elevation: 15,
)
```

### Photo Gallery

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
    VColumn(
      spacing: 30,
      stagger: StaggerConfig.slideUp(delay: 20, duration: 35),
      children: [
        VRow(
          spacing: 25,
          children: [
            PhotoCard.withKenBurns(
              assetPath: 'assets/photo1.jpg',
              width: 300,
              height: 220,
              zoomAmount: 0.1,
            ),
            PhotoCard.withKenBurns(
              assetPath: 'assets/photo2.jpg',
              width: 300,
              height: 220,
              zoomAmount: 0.1,
            ),
          ],
        ),
        VRow(
          spacing: 25,
          children: [
            PhotoCard.withKenBurns(
              assetPath: 'assets/photo3.jpg',
              width: 300,
              height: 220,
              zoomAmount: 0.1,
            ),
            PhotoCard.withKenBurns(
              assetPath: 'assets/photo4.jpg',
              width: 300,
              height: 220,
              zoomAmount: 0.1,
            ),
          ],
        ),
      ],
    ),
  ],
)
```

### Animated Entry

```dart
Scene(
  durationInFrames: 180,
  children: [
    AnimatedPhotoCard(
      assetPath: 'assets/hero.jpg',
      width: 600,
      height: 400,
      startFrame: 30,
      animationDuration: 40,
      slideFrom: SlideFromDirection.bottom,
      slideDistance: 100,
      curve: Curves.easeOutBack,
      kenBurns: true,
    ),
  ],
)
```

### Staggered Gallery

```dart
Scene(
  durationInFrames: 240,
  children: [
    VPositioned(
      left: 100,
      top: 100,
      child: AnimatedPhotoCard(
        assetPath: 'assets/photo1.jpg',
        width: 280,
        height: 200,
        startFrame: 0,
        slideFrom: SlideFromDirection.left,
      ),
    ),
    VPositioned(
      left: 420,
      top: 120,
      child: AnimatedPhotoCard(
        assetPath: 'assets/photo2.jpg',
        width: 280,
        height: 200,
        startFrame: 15,
        slideFrom: SlideFromDirection.right,
      ),
    ),
    VPositioned(
      left: 260,
      top: 350,
      child: AnimatedPhotoCard(
        assetPath: 'assets/photo3.jpg',
        width: 280,
        height: 200,
        startFrame: 30,
        slideFrom: SlideFromDirection.bottom,
      ),
    ),
  ],
)
```

### Error Handling

```dart
PhotoCard(
  assetPath: 'assets/might_not_exist.jpg',
  width: 400,
  height: 300,
  errorBuilder: (context, error, stack) => Container(
    color: Colors.grey[300],
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image, size: 48, color: Colors.grey),
          SizedBox(height: 8),
          Text('Image not found', style: TextStyle(color: Colors.grey)),
        ],
      ),
    ),
  ),
)
```

---

## Ken Burns vs Collage

| Use Case | Widget |
|----------|--------|
| Single featured photo | `PhotoCard.withKenBurns` |
| Multiple static photos | `Collage` |
| Photo with animation | `AnimatedPhotoCard` |
| Vintage instant photo | `PolaroidFrame` |

---

## Related

- [KenBurnsImage](ken-burns-image.md) - Standalone Ken Burns effect
- [PolaroidFrame](polaroid-frame.md) - Polaroid style frame
- [Collage](../widgets/media/collage.md) - Photo layouts
- [PropAnimation](../animations/prop-animation.md) - Custom animations
