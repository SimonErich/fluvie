# Embedding Images

> **Using images in Fluvie compositions**

Images are fundamental building blocks in video compositions. This guide covers how to embed, animate, and optimize images in Fluvie.

## Table of Contents

- [Basic Usage](#basic-usage)
- [Image Sources](#image-sources)
- [Sizing and Fitting](#sizing-and-fitting)
- [Animating Images](#animating-images)
- [Ken Burns Effect](#ken-burns-effect)
- [Image Grids](#image-grids)
- [Best Practices](#best-practices)

---

## Basic Usage

Standard Flutter image widgets work in Fluvie:

```dart
Scene(
  durationInFrames: 150,
  children: [
    VPositioned.fill(
      child: Image.asset(
        'assets/background.jpg',
        fit: BoxFit.cover,
      ),
    ),
  ],
)
```

---

## Image Sources

### Asset Images

Load images from your Flutter assets:

```dart
// Register in pubspec.yaml first
// flutter:
//   assets:
//     - assets/images/

Image.asset(
  'assets/images/photo.jpg',
  fit: BoxFit.cover,
)
```

### Network Images

Load images from URLs (cached during render):

```dart
Image.network(
  'https://example.com/photo.jpg',
  fit: BoxFit.cover,
  loadingBuilder: (context, child, loadingProgress) {
    if (loadingProgress == null) return child;
    return Container(color: Colors.grey);
  },
)
```

### File Images

Load from the local filesystem:

```dart
Image.file(
  File('/path/to/image.jpg'),
  fit: BoxFit.cover,
)
```

### Memory Images

Load from bytes in memory:

```dart
Image.memory(
  imageBytes,
  fit: BoxFit.cover,
)
```

---

## Sizing and Fitting

### BoxFit Options

```dart
// Cover: Fill container, may crop
Image.asset('photo.jpg', fit: BoxFit.cover)

// Contain: Fit within container, may letterbox
Image.asset('photo.jpg', fit: BoxFit.contain)

// Fill: Stretch to fill (may distort)
Image.asset('photo.jpg', fit: BoxFit.fill)

// Fixed dimensions
SizedBox(
  width: 400,
  height: 300,
  child: Image.asset('photo.jpg', fit: BoxFit.cover),
)
```

### Full-Screen Background

```dart
Scene(
  durationInFrames: 150,
  children: [
    VPositioned.fill(
      child: Image.asset(
        'assets/background.jpg',
        fit: BoxFit.cover,
        alignment: Alignment.center,  // Control crop position
      ),
    ),
    // Other content on top...
  ],
)
```

### Centered with Constraints

```dart
VCenter(
  child: ConstrainedBox(
    constraints: BoxConstraints(maxWidth: 600, maxHeight: 400),
    child: Image.asset(
      'assets/photo.jpg',
      fit: BoxFit.contain,
    ),
  ),
)
```

---

## Animating Images

### Entry Animation

```dart
AnimatedProp(
  startFrame: 30,
  duration: 45,
  animation: PropAnimation.combine([
    PropAnimation.zoomIn(start: 0.8),
    PropAnimation.fadeIn(),
  ]),
  curve: Easing.easeOutBack,
  child: Image.asset('assets/photo.jpg'),
)
```

### Sliding Image

```dart
AnimatedProp(
  startFrame: 0,
  duration: 60,
  animation: PropAnimation.slideUp(distance: 100),
  child: Image.asset('assets/photo.jpg'),
)
```

### Rotating Image

```dart
AnimatedProp(
  startFrame: 0,
  duration: 90,
  animation: PropAnimation.rotate(
    start: -0.1,
    end: 0.1,
  ),
  child: Image.asset('assets/photo.jpg'),
)
```

### Continuous Animation with TimeConsumer

```dart
TimeConsumer(
  builder: (context, frame, fps) {
    final rotation = frame * 0.01;  // Slow continuous rotation
    return Transform.rotate(
      angle: rotation,
      child: Image.asset('assets/logo.png'),
    );
  },
)
```

---

## Ken Burns Effect

The Ken Burns effect creates cinematic movement on still images:

### Using KenBurnsImage

```dart
KenBurnsImage(
  assetPath: 'assets/landscape.jpg',
  width: 800,
  height: 600,
  startScale: 1.0,
  endScale: 1.3,
  startAlignment: Alignment.centerLeft,
  endAlignment: Alignment.centerRight,
)
```

### Zoom In

```dart
KenBurnsImage.zoomIn(
  assetPath: 'assets/portrait.jpg',
  width: 600,
  height: 800,
  zoomAmount: 0.2,
  focus: Alignment.center,
)
```

### Pan Across

```dart
KenBurnsImage.pan(
  assetPath: 'assets/panorama.jpg',
  width: 1200,
  height: 400,
  from: Alignment.centerLeft,
  to: Alignment.centerRight,
  scale: 1.2,
)
```

---

## Image Grids

### Using VRow and VColumn

```dart
VColumn(
  spacing: 10,
  children: [
    VRow(
      spacing: 10,
      children: [
        Expanded(child: Image.asset('photo1.jpg', fit: BoxFit.cover)),
        Expanded(child: Image.asset('photo2.jpg', fit: BoxFit.cover)),
      ],
    ),
    VRow(
      spacing: 10,
      children: [
        Expanded(child: Image.asset('photo3.jpg', fit: BoxFit.cover)),
        Expanded(child: Image.asset('photo4.jpg', fit: BoxFit.cover)),
      ],
    ),
  ],
)
```

### With Stagger Animation

```dart
VColumn(
  spacing: 10,
  stagger: StaggerConfig.scale(delay: 10, duration: 30),
  children: [
    Image.asset('photo1.jpg'),
    Image.asset('photo2.jpg'),
    Image.asset('photo3.jpg'),
  ],
)
```

---

## Clipping and Borders

### Rounded Corners

```dart
ClipRRect(
  borderRadius: BorderRadius.circular(20),
  child: Image.asset(
    'assets/photo.jpg',
    fit: BoxFit.cover,
    width: 300,
    height: 200,
  ),
)
```

### Circular Image

```dart
ClipOval(
  child: Image.asset(
    'assets/profile.jpg',
    fit: BoxFit.cover,
    width: 150,
    height: 150,
  ),
)
```

### With Border

```dart
Container(
  decoration: BoxDecoration(
    border: Border.all(color: Colors.white, width: 4),
    borderRadius: BorderRadius.circular(20),
  ),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: Image.asset('assets/photo.jpg', fit: BoxFit.cover),
  ),
)
```

### Custom Shape

```dart
ClipPath(
  clipper: MyCustomClipper(),
  child: Image.asset('assets/photo.jpg'),
)
```

---

## Error Handling

### With Placeholder

```dart
Image.asset(
  'assets/photo.jpg',
  fit: BoxFit.cover,
  errorBuilder: (context, error, stackTrace) {
    return Container(
      color: Colors.grey[800],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, size: 48, color: Colors.grey),
          Text('Image not found', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  },
)
```

### Fallback Chain

```dart
Widget buildImage(String? path) {
  if (path == null) {
    return _buildPlaceholder();
  }

  return Image.asset(
    path,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => _buildPlaceholder(),
  );
}

Widget _buildPlaceholder() {
  return Container(
    color: Colors.grey[800],
    child: Icon(Icons.image, color: Colors.grey),
  );
}
```

---

## Best Practices

### 1. Match Resolution to Output

```dart
// For 1080x1920 output, use similarly sized images
// Don't load 4K images if output is 1080p

// Good
Image.asset('assets/bg_1080.jpg')  // 1080x1920

// Wasteful
Image.asset('assets/bg_4k.jpg')    // 2160x3840
```

### 2. Use Appropriate Formats

| Use Case | Format | Why |
|----------|--------|-----|
| Photos | JPEG | Smaller file size |
| Transparency | PNG | Alpha channel support |
| Logos/icons | PNG/SVG | Crisp edges |
| Simple graphics | PNG | Lossless |

### 3. Preload Critical Images

```dart
// In initState or before rendering
await precacheImage(AssetImage('assets/important.jpg'), context);
```

### 4. Organize Assets

```
assets/
├── images/
│   ├── backgrounds/
│   │   ├── gradient_dark.jpg
│   │   └── texture_noise.png
│   ├── photos/
│   │   ├── photo_001.jpg
│   │   └── photo_002.jpg
│   └── ui/
│       ├── logo.png
│       └── icon_play.png
```

### 5. Consider Memory

For compositions with many images, consider:
- Loading images on demand
- Using lower resolution previews
- Clearing image cache between scenes

---

## Related

- [Ken Burns Image](../helpers/ken-burns-image.md)
- [Photo Card](../helpers/photo-card.md)
- [Polaroid Frame](../helpers/polaroid-frame.md)
- [Videos](videos.md)
