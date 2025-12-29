# Helper Widgets

Fluvie provides pre-built helper widgets for common video composition patterns like photo displays, statistics, and animated elements.

## Overview

| Widget | Description | Use Case |
|--------|-------------|----------|
| [PolaroidFrame](polaroid-frame.md) | Instant photo style frame | Nostalgic photo display |
| [PhotoCard](photo-card.md) | Modern photo card with effects | Photo galleries |
| [StatCard](stat-card.md) | Animated statistic display | Metrics, counts |
| [FloatingElement](floating-element.md) | Oscillating float animation | Dynamic elements |
| [KenBurnsImage](ken-burns-image.md) | Cinematic pan and zoom | Photo slideshows |

---

## Quick Examples

### Polaroid Frame

```dart
PolaroidFrame(
  size: Size(300, 350),
  caption: 'Summer 2024',
  rotation: 0.05,
  child: Image.asset('photo.jpg', fit: BoxFit.cover),
)
```

### Photo Card with Ken Burns

```dart
PhotoCard.withKenBurns(
  assetPath: 'assets/photo.jpg',
  width: 400,
  height: 300,
  zoomAmount: 0.15,
  focus: Alignment.center,
)
```

### Animated Statistic

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

### Floating Element

```dart
FloatingElement(
  position: Offset(100, 200),
  floatAmplitude: Offset(0, 10),
  floatFrequency: 0.5,
  child: Image.asset('cloud.png'),
)
```

### Ken Burns Image

```dart
KenBurnsImage.zoomAndPan(
  assetPath: 'assets/landscape.jpg',
  width: 800,
  height: 600,
  startScale: 1.0,
  endScale: 1.3,
  from: Alignment.centerLeft,
  to: Alignment.centerRight,
)
```

---

## Common Patterns

### Photo Gallery

```dart
Scene(
  durationInFrames: 300,
  children: [
    VRow(
      spacing: 20,
      stagger: StaggerConfig.scale(delay: 15),
      children: [
        PhotoCard.withKenBurns(
          assetPath: 'assets/photo1.jpg',
          width: 280,
          height: 200,
        ),
        PhotoCard.withKenBurns(
          assetPath: 'assets/photo2.jpg',
          width: 280,
          height: 200,
        ),
        PhotoCard.withKenBurns(
          assetPath: 'assets/photo3.jpg',
          width: 280,
          height: 200,
        ),
      ],
    ),
  ],
)
```

### Statistics Dashboard

```dart
VRow(
  spacing: 30,
  stagger: StaggerConfig.slideUp(delay: 15),
  children: [
    StatCard(
      value: 365,
      label: 'Days',
      color: Colors.blue,
      startFrame: 30,
    ),
    StatCard(
      value: 1234,
      label: 'Photos',
      color: Colors.green,
      startFrame: 45,
    ),
    StatCard.percentage(
      value: 95,
      label: 'Completed',
      color: Colors.orange,
      startFrame: 60,
    ),
  ],
)
```

### Memory Wall

```dart
LayerStack(
  children: [
    // Scattered polaroids at different angles
    VPositioned(
      left: 50,
      top: 100,
      child: PolaroidFrame.tilted(
        tiltDegrees: -5,
        caption: 'Beach Day',
        child: Image.asset('beach.jpg'),
      ),
    ),
    VPositioned(
      left: 320,
      top: 80,
      child: PolaroidFrame.tilted(
        tiltDegrees: 3,
        caption: 'Mountains',
        child: Image.asset('mountains.jpg'),
      ),
    ),
    VPositioned(
      left: 180,
      top: 350,
      child: PolaroidFrame.tilted(
        tiltDegrees: -2,
        caption: 'City Lights',
        child: Image.asset('city.jpg'),
      ),
    ),
  ],
)
```

### Floating Decorations

```dart
Scene(
  durationInFrames: 300,
  children: [
    // Main content
    VCenter(child: MainContent()),

    // Floating decorative elements
    FloatingElement(
      position: Offset(100, 150),
      floatAmplitude: Offset(5, 12),
      floatPhase: 0.0,
      child: Icon(Icons.star, size: 32, color: Colors.yellow),
    ),
    FloatingElement(
      position: Offset(800, 200),
      floatAmplitude: Offset(8, 10),
      floatPhase: 0.3,
      child: Icon(Icons.star, size: 24, color: Colors.yellow),
    ),
    FloatingElement(
      position: Offset(600, 450),
      floatAmplitude: Offset(6, 15),
      floatPhase: 0.6,
      child: Icon(Icons.star, size: 28, color: Colors.yellow),
    ),
  ],
)
```

---

## Related

- [Collage](../widgets/media/collage.md) - Photo grid layouts
- [EmbeddedVideo](../widgets/media/embedded-video.md) - Video clips
- [PropAnimation](../animations/prop-animation.md) - Custom animations
