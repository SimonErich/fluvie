# Embedding Videos

> **Including video clips in Fluvie compositions**

Embed existing video clips into your compositions with trimming, positioning, and audio control.

## Table of Contents

- [Overview](#overview)
- [EmbeddedVideo Widget](#embeddedvideo-widget)
- [Trimming and Timing](#trimming-and-timing)
- [Audio from Videos](#audio-from-videos)
- [Positioning Videos](#positioning-videos)
- [Multiple Video Clips](#multiple-video-clips)
- [Best Practices](#best-practices)

---

## Overview

Fluvie can embed video files into your compositions. During rendering:

1. **Frame Extraction**: Video frames are extracted at your composition's FPS
2. **Caching**: Extracted frames are cached for efficiency
3. **Compositing**: Video frames are composited with other widgets
4. **Audio Mixing**: Video audio is mixed with other audio tracks

### Supported Formats

Any format supported by FFmpeg:
- MP4 (H.264, H.265)
- MOV
- WebM
- AVI
- MKV
- And many more

---

## EmbeddedVideo Widget

### Basic Usage

```dart
Scene(
  durationInFrames: 150,
  children: [
    EmbeddedVideo(
      assetPath: 'assets/video.mp4',
      startFrame: 0,
      durationInFrames: 150,
    ),
  ],
)
```

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `assetPath` | `String` | **required** | Path to video file |
| `startFrame` | `int` | `0` | Frame to start showing video |
| `durationInFrames` | `int?` | `null` | How long to show (null = full length) |
| `trimStart` | `Duration?` | `null` | Skip beginning of video |
| `trimEnd` | `Duration?` | `null` | Stop at this point in video |
| `volume` | `double` | `1.0` | Audio volume (0.0 - 1.0) |
| `fit` | `BoxFit` | `cover` | How video fits container |
| `alignment` | `Alignment` | `center` | Position within container |
| `playbackSpeed` | `double` | `1.0` | Speed multiplier |
| `loop` | `bool` | `false` | Loop when reaching end |

---

## Trimming and Timing

### Use Part of a Video

```dart
EmbeddedVideo(
  assetPath: 'assets/footage.mp4',
  // Skip first 10 seconds of source video
  trimStart: Duration(seconds: 10),
  // Stop at 25 seconds of source video
  trimEnd: Duration(seconds: 25),
  // Display for 5 seconds in composition (at 30fps)
  startFrame: 30,
  durationInFrames: 150,
)
```

### Timeline Visualization

```
Source Video:    [0s----10s====15s====20s====25s----30s]
                          ↓ trimStart    trimEnd ↓
Trimmed Section:         [=====15 seconds=====]
                                  ↓
Composition:     [Frame 30------------------Frame 180]
                     ↑ startFrame    durationInFrames=150
```

### Speed Up Video

```dart
EmbeddedVideo(
  assetPath: 'assets/timelapse.mp4',
  startFrame: 0,
  durationInFrames: 90,
  playbackSpeed: 2.0,  // 2x speed
)
```

### Slow Motion

```dart
EmbeddedVideo(
  assetPath: 'assets/action.mp4',
  startFrame: 0,
  durationInFrames: 180,
  playbackSpeed: 0.5,  // Half speed
)
```

---

## Audio from Videos

### Include Video Audio

```dart
EmbeddedVideo(
  assetPath: 'assets/clip.mp4',
  startFrame: 0,
  durationInFrames: 150,
  volume: 1.0,  // Full volume
)
```

### Mute Video

```dart
EmbeddedVideo(
  assetPath: 'assets/clip.mp4',
  startFrame: 0,
  durationInFrames: 150,
  volume: 0.0,  // Muted
)
```

### Lower Video Audio for Background Music

```dart
Video(
  scenes: [
    Scene(
      durationInFrames: 300,
      children: [
        EmbeddedVideo(
          assetPath: 'assets/interview.mp4',
          volume: 0.3,  // Lower to hear music
        ),
      ],
    ),
  ],
  audioTracks: [
    AudioTrack(
      source: AudioSource.asset('assets/background_music.mp3'),
      volume: 0.7,
    ),
  ],
)
```

---

## Positioning Videos

### Full Screen

```dart
VPositioned.fill(
  child: EmbeddedVideo(
    assetPath: 'assets/background.mp4',
    fit: BoxFit.cover,
  ),
)
```

### Fixed Size

```dart
VCenter(
  child: SizedBox(
    width: 640,
    height: 360,
    child: EmbeddedVideo(
      assetPath: 'assets/clip.mp4',
      fit: BoxFit.contain,
    ),
  ),
)
```

### Corner Position

```dart
VPositioned(
  right: 20,
  bottom: 20,
  child: SizedBox(
    width: 320,
    height: 180,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: EmbeddedVideo(
        assetPath: 'assets/pip.mp4',
        fit: BoxFit.cover,
      ),
    ),
  ),
)
```

### Picture-in-Picture Layout

```dart
Scene(
  durationInFrames: 300,
  children: [
    // Main video (full screen)
    VPositioned.fill(
      child: EmbeddedVideo(
        assetPath: 'assets/main.mp4',
        fit: BoxFit.cover,
      ),
    ),

    // PiP video (corner)
    VPositioned(
      right: 40,
      top: 40,
      child: Container(
        width: 300,
        height: 170,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 10,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: EmbeddedVideo(
            assetPath: 'assets/pip.mp4',
            fit: BoxFit.cover,
            volume: 0.0,  // Mute PiP
          ),
        ),
      ),
    ),
  ],
)
```

---

## Multiple Video Clips

### Sequential Clips

```dart
Video(
  fps: 30,
  width: 1920,
  height: 1080,
  scenes: [
    Scene(
      durationInFrames: 150,
      children: [
        VPositioned.fill(
          child: EmbeddedVideo(assetPath: 'assets/clip1.mp4'),
        ),
      ],
    ),
    Scene(
      durationInFrames: 150,
      transitionIn: SceneTransition.crossFade(durationInFrames: 20),
      children: [
        VPositioned.fill(
          child: EmbeddedVideo(assetPath: 'assets/clip2.mp4'),
        ),
      ],
    ),
    Scene(
      durationInFrames: 150,
      transitionIn: SceneTransition.crossFade(durationInFrames: 20),
      children: [
        VPositioned.fill(
          child: EmbeddedVideo(assetPath: 'assets/clip3.mp4'),
        ),
      ],
    ),
  ],
)
```

### Side-by-Side

```dart
Scene(
  durationInFrames: 180,
  children: [
    VRow(
      children: [
        Expanded(
          child: EmbeddedVideo(
            assetPath: 'assets/left.mp4',
            fit: BoxFit.cover,
            volume: 0.5,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: EmbeddedVideo(
            assetPath: 'assets/right.mp4',
            fit: BoxFit.cover,
            volume: 0.5,
          ),
        ),
      ],
    ),
  ],
)
```

### Overlapping Videos

```dart
Scene(
  durationInFrames: 180,
  children: [
    // Background video
    VPositioned.fill(
      child: EmbeddedVideo(
        assetPath: 'assets/background.mp4',
        fit: BoxFit.cover,
        volume: 0.0,
      ),
    ),

    // Overlay video (with transparency)
    VPositioned.fill(
      child: Opacity(
        opacity: 0.5,
        child: EmbeddedVideo(
          assetPath: 'assets/overlay.mp4',
          fit: BoxFit.cover,
          volume: 0.0,
        ),
      ),
    ),
  ],
)
```

---

## Looping Videos

### Auto-Loop

```dart
Scene(
  durationInFrames: 300,  // 10 seconds
  children: [
    VPositioned.fill(
      child: EmbeddedVideo(
        assetPath: 'assets/short_loop.mp4',  // 2-second clip
        loop: true,  // Will loop ~5 times
        volume: 0.0,
      ),
    ),
  ],
)
```

---

## Best Practices

### 1. Pre-Process Videos

For best performance, pre-process your source videos:

```bash
# Transcode to consistent format
ffmpeg -i input.mp4 -c:v libx264 -preset medium -crf 23 output.mp4

# Trim externally for large files
ffmpeg -i input.mp4 -ss 00:00:10 -t 00:00:15 -c copy trimmed.mp4
```

### 2. Match Frame Rates

Use source videos with the same FPS as your composition when possible:

```dart
Video(
  fps: 30,  // Composition FPS
  scenes: [
    Scene(
      children: [
        // Best: source is also 30fps
        EmbeddedVideo(assetPath: 'assets/30fps_clip.mp4'),
      ],
    ),
  ],
)
```

### 3. Consider File Size

- Large video files take longer to extract frames
- Consider pre-trimming long videos
- Use appropriate resolution for output

### 4. Handle Missing Videos

```dart
Widget buildVideo(String? path) {
  if (path == null) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Icon(Icons.videocam_off, color: Colors.grey),
      ),
    );
  }

  return EmbeddedVideo(
    assetPath: path,
    fit: BoxFit.cover,
  );
}
```

### 5. Disk Space Awareness

Frame extraction creates temporary files:

```
1 minute of 1080p video at 30fps:
≈ 1800 frames × ~500KB each = ~900MB temporary storage
```

---

## Related

- [Video Sequence](../widgets/media/video-sequence.md) - Multiple video clips in sequence
- [Audio](audio.md) - Audio tracks and mixing
- [Frame Extraction](../advanced/frame-extraction.md) - How extraction works
- [Performance Tips](../advanced/performance-tips.md)
