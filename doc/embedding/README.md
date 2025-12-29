# Embedding Media

> **Guide to including images, videos, audio, and fonts in your Fluvie compositions**

Fluvie supports embedding various media types into your video compositions. This section covers best practices and usage patterns for each type.

## Table of Contents

- [Overview](#overview)
- [Media Types](#media-types)
- [Best Practices](#best-practices)
- [Related Guides](#related-guides)

---

## Overview

Fluvie compositions can include:

| Media Type | Widget/Class | Usage |
|------------|--------------|-------|
| **Images** | `Image.asset()`, `Image.network()` | Static and animated images |
| **Videos** | `EmbeddedVideo` | Video clips with trimming |
| **Audio** | `AudioTrack`, `BackgroundAudio` | Music and sound effects |
| **Fonts** | `TextStyle` | Custom typography |

### How Embedding Works

During **preview mode**, media plays directly using Flutter's built-in capabilities.

During **render mode**, Fluvie:
1. Extracts frames from video files
2. Captures widget frames as images
3. Assembles everything with FFmpeg
4. Mixes audio tracks at specified volumes

---

## Media Types

### Images

Standard Flutter image widgets work seamlessly:

```dart
// Asset images
Image.asset('assets/photo.jpg', fit: BoxFit.cover)

// Network images (cached during render)
Image.network('https://example.com/photo.jpg')

// With animation
AnimatedProp(
  startFrame: 30,
  animation: PropAnimation.zoomIn(),
  child: Image.asset('assets/logo.png'),
)
```

See: [Images Guide](images.md)

### Videos

Embed video clips using the `EmbeddedVideo` widget:

```dart
EmbeddedVideo(
  assetPath: 'assets/clip.mp4',
  startFrame: 60,
  durationInFrames: 150,
  trimStart: Duration(seconds: 5),
  volume: 0.8,
)
```

See: [Videos Guide](videos.md)

### Audio

Add audio tracks for music and sound effects:

```dart
Video(
  scenes: [...],
  audioTracks: [
    AudioTrack(
      source: AudioSource.asset('assets/music.mp3'),
      volume: 0.8,
      fadeInFrames: 30,
      fadeOutFrames: 60,
    ),
  ],
)
```

See: [Audio Guide](audio.md)

### Fonts

Use custom fonts by loading them in your app:

```dart
// In pubspec.yaml
fonts:
  - family: MyCustomFont
    fonts:
      - asset: assets/fonts/MyFont-Regular.ttf
      - asset: assets/fonts/MyFont-Bold.ttf
        weight: 700

// In your composition
Text(
  'Hello World',
  style: TextStyle(
    fontFamily: 'MyCustomFont',
    fontSize: 48,
  ),
)
```

See: [Fonts Guide](fonts.md)

---

## Best Practices

### 1. Optimize Image Sizes

```dart
// Don't load 4K images for 1080p output
// Pre-scale images to match your output resolution

// Good: 1080x1920 image for 1080x1920 video
Image.asset('assets/background_1080.jpg')

// Wasteful: 4K image scaled down at runtime
Image.asset('assets/background_4k.jpg')  // Avoid
```

### 2. Use Appropriate Formats

| Use Case | Recommended Format |
|----------|-------------------|
| Photos | JPEG (smaller size) |
| Graphics with transparency | PNG |
| Animations | GIF or video |
| Icons/logos | SVG (via flutter_svg) or PNG |

### 3. Handle Loading States

```dart
Image.asset(
  'assets/photo.jpg',
  fit: BoxFit.cover,
  errorBuilder: (context, error, stackTrace) {
    return Container(
      color: Colors.grey,
      child: Icon(Icons.error),
    );
  },
)
```

### 4. Audio Timing

- Start audio slightly before visual elements for better sync
- Use `fadeInFrames` and `fadeOutFrames` for smooth transitions
- Match audio duration to video length

### 5. Video Trimming

```dart
// Use trimStart and trimEnd for precise control
EmbeddedVideo(
  assetPath: 'assets/footage.mp4',
  trimStart: Duration(seconds: 5),   // Skip first 5 seconds
  trimEnd: Duration(seconds: 15),    // Stop at 15 seconds
  durationInFrames: 300,             // Play for 10 seconds at 30fps
)
```

---

## Asset Organization

Recommended project structure:

```
project/
├── assets/
│   ├── images/
│   │   ├── backgrounds/
│   │   ├── photos/
│   │   └── logos/
│   ├── videos/
│   │   ├── clips/
│   │   └── overlays/
│   ├── audio/
│   │   ├── music/
│   │   └── sfx/
│   └── fonts/
├── lib/
│   └── ...
└── pubspec.yaml
```

Register assets in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/images/
    - assets/videos/
    - assets/audio/
```

---

## Memory Considerations

### Large Videos

- Fluvie extracts video frames to temporary storage
- Large videos can consume significant disk space
- Consider pre-trimming long videos externally

### Many Images

- Images are loaded into memory during preview
- Use appropriate resolution for your output
- Consider lazy loading for galleries

### Audio Files

- Compressed formats (MP3, AAC) recommended
- WAV files work but are larger
- Multiple audio tracks are mixed at render time

---

## Related Guides

- [Images](images.md) - Detailed image embedding guide
- [Videos](videos.md) - Video embedding and trimming
- [Audio](audio.md) - Audio tracks and mixing
- [Fonts](fonts.md) - Custom typography
- [Performance Tips](../advanced/performance-tips.md) - Optimization strategies
