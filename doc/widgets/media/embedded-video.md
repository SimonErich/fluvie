# EmbeddedVideo

> **Display synchronized video frames within your composition**

`EmbeddedVideo` extracts and displays frames from a video file in sync with the composition timeline. It handles frame extraction, caching, and audio integration automatically.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Examples](#examples)
- [Audio Integration](#audio-integration)
- [Performance](#performance)
- [Related](#related)

---

## Overview

`EmbeddedVideo` is the recommended way to include external video clips in your composition:

```dart
EmbeddedVideo(
  assetPath: 'assets/highlight.mp4',
  width: 900,
  height: 500,
  startFrame: 40,
  trimStart: Duration(seconds: 2),
  fit: BoxFit.cover,
  includeAudio: true,
)
```

### How It Works

1. FFmpeg extracts frames from the source video
2. Frames are cached for smooth playback
3. Background preloading keeps frames ready ahead of playback
4. Audio is optionally mixed into the final render

---

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `assetPath` | `String` | **required** | Path to video (asset, file, or URL) |
| `width` | `double?` | `null` | Display width |
| `height` | `double?` | `null` | Display height |
| `startFrame` | `int` | `0` | Frame to start showing video |
| `trimStart` | `Duration` | `0` | Skip this much at start of source |
| `durationInFrames` | `int?` | `null` | Override duration (auto-calculated if null) |
| `fit` | `BoxFit` | `cover` | How video fits in bounds |
| `borderRadius` | `BorderRadius?` | `null` | Corner rounding |
| `decoration` | `BoxDecoration?` | `null` | Container decoration |
| `placeholder` | `Widget?` | `null` | Widget shown before video starts |
| `errorWidget` | `Widget?` | `null` | Widget shown on error |
| `includeAudio` | `bool` | `true` | Include audio in final render |
| `audioVolume` | `double` | `1.0` | Audio volume (0.0-1.0) |
| `audioFadeInFrames` | `int` | `0` | Audio fade-in duration |
| `audioFadeOutFrames` | `int` | `0` | Audio fade-out duration |
| `preloadFrames` | `int` | `30` | Frames to preload ahead |
| `id` | `String?` | `null` | Unique identifier |

---

## Examples

### Basic Usage

```dart
EmbeddedVideo(
  assetPath: 'assets/clip.mp4',
  width: 800,
  height: 450,
)
```

### With Timing

```dart
EmbeddedVideo(
  assetPath: 'assets/highlight.mp4',
  width: 640,
  height: 360,
  startFrame: 60,  // Start at 2 seconds (30fps)
  durationInFrames: 150,  // Play for 5 seconds
)
```

### Trimmed Source

```dart
// Skip the first 5 seconds of the source video
EmbeddedVideo(
  assetPath: 'assets/long_video.mp4',
  width: 800,
  height: 450,
  trimStart: Duration(seconds: 5),
)
```

### Styled Container

```dart
EmbeddedVideo(
  assetPath: 'assets/clip.mp4',
  width: 600,
  height: 400,
  borderRadius: BorderRadius.circular(20),
  decoration: BoxDecoration(
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.3),
        blurRadius: 15,
        offset: Offset(0, 8),
      ),
    ],
  ),
)
```

### In a Scene

```dart
Scene(
  durationInFrames: 240,
  background: Background.solid(Colors.black),
  children: [
    // Video with fade-in
    VPositioned(
      left: 100,
      top: 100,
      startFrame: 30,
      fadeInFrames: 20,
      child: EmbeddedVideo(
        assetPath: 'assets/highlight.mp4',
        width: 800,
        height: 450,
        startFrame: 30,  // Matches parent timing
        fit: BoxFit.cover,
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    // Caption below video
    VPositioned(
      left: 100,
      right: 100,
      bottom: 50,
      startFrame: 60,
      fadeInFrames: 15,
      child: Text(
        'Your favorite moment',
        style: TextStyle(color: Colors.white, fontSize: 24),
      ),
    ),
  ],
)
```

### Different Source Types

```dart
// From Flutter assets
EmbeddedVideo(assetPath: 'assets/video.mp4')

// From file system
EmbeddedVideo(assetPath: '/path/to/video.mp4')

// From URL
EmbeddedVideo(assetPath: 'https://example.com/video.mp4')
```

### Full Screen Video

```dart
VPositioned.fill(
  child: EmbeddedVideo(
    assetPath: 'assets/background.mp4',
    fit: BoxFit.cover,
    includeAudio: false,  // Background video, no audio
  ),
)
```

---

## Audio Integration

### Default Behavior

By default, audio from the embedded video is included in the final render:

```dart
EmbeddedVideo(
  assetPath: 'assets/clip.mp4',
  includeAudio: true,  // Default
)
```

### Audio Control

```dart
EmbeddedVideo(
  assetPath: 'assets/clip.mp4',
  includeAudio: true,
  audioVolume: 0.7,        // 70% volume
  audioFadeInFrames: 30,   // 1 second fade in
  audioFadeOutFrames: 30,  // 1 second fade out
)
```

### Muting Audio

```dart
// Background video without audio
EmbeddedVideo(
  assetPath: 'assets/background_loop.mp4',
  includeAudio: false,
)
```

### Mixing with Background Music

```dart
LayerStack(
  children: [
    // Background music at lower volume
    BackgroundAudio(
      source: AudioSource.asset('assets/music.mp3'),
      volume: 0.3,  // Lower to make room for video audio
      child: const SizedBox.shrink(),
    ),

    // Video with its own audio
    EmbeddedVideo(
      assetPath: 'assets/clip.mp4',
      width: 800,
      height: 450,
      includeAudio: true,
      audioVolume: 0.8,
    ),
  ],
)
```

---

## Performance

### Preloading

Frames are preloaded ahead of playback for smooth performance:

```dart
EmbeddedVideo(
  assetPath: 'assets/video.mp4',
  preloadFrames: 60,  // Preload 2 seconds ahead at 30fps
)
```

### Frame Caching

Extracted frames are automatically cached. The cache is managed internally to balance memory usage and performance.

### Best Practices

1. **Keep videos short** - Long videos use more memory
2. **Match resolution** - Use videos close to display size
3. **Consider format** - MP4 with H.264 is widely compatible
4. **Trim in advance** - Pre-trim source videos when possible

### Memory Considerations

```dart
// High memory: Large video, many preload frames
EmbeddedVideo(
  assetPath: 'assets/4k_video.mp4',
  width: 1920,
  height: 1080,
  preloadFrames: 120,  // 4 seconds of 1080p frames
)

// Low memory: Smaller display, fewer preload frames
EmbeddedVideo(
  assetPath: 'assets/video.mp4',
  width: 480,
  height: 270,
  preloadFrames: 15,  // Half second of smaller frames
)
```

---

## Error Handling

### Custom Error Widget

```dart
EmbeddedVideo(
  assetPath: 'assets/video.mp4',
  width: 640,
  height: 360,
  errorWidget: Container(
    color: Colors.grey[800],
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam_off, size: 48, color: Colors.white54),
          SizedBox(height: 8),
          Text('Video unavailable', style: TextStyle(color: Colors.white54)),
        ],
      ),
    ),
  ),
)
```

### Custom Placeholder

```dart
EmbeddedVideo(
  assetPath: 'assets/video.mp4',
  width: 640,
  height: 360,
  placeholder: Container(
    color: Colors.black,
    child: Center(
      child: Icon(Icons.movie, size: 64, color: Colors.white30),
    ),
  ),
)
```

---

## Related

- [VideoSequence](video-sequence.md) - Low-level video sequence
- [Embedding Videos](../../embedding/videos.md) - Detailed guide
- [AudioTrack](../audio/audio-track.md) - Audio control
