# BackgroundAudio

> **Convenience widget for full-video background music**

`BackgroundAudio` is a simplified wrapper around `AudioTrack` that automatically spans the entire video duration. It's the easiest way to add background music.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Examples](#examples)
- [Comparison with AudioTrack](#comparison-with-audiotrack)
- [Related](#related)

---

## Overview

`BackgroundAudio` automatically reads the video duration from `VideoComposition` and creates an `AudioTrack` that spans the full timeline:

```dart
VideoComposition(
  fps: 30,
  durationInFrames: 300,
  width: 1920,
  height: 1080,
  child: BackgroundAudio(
    source: AudioSource.asset('assets/audio/music.mp3'),
    volume: 0.7,
    fadeInFrames: 30,
    fadeOutFrames: 60,
    child: MyContent(),
  ),
)
```

### When to Use

Use `BackgroundAudio` when you want:
- Simple background music for the entire video
- Automatic duration matching
- Less configuration than `AudioTrack`

Use `AudioTrack` instead when you need:
- Audio that starts/stops at specific frames
- Multiple audio clips with different timing
- Sync anchors

---

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `source` | `AudioSource` | **required** | The audio file |
| `trimStartFrame` | `int` | `0` | Skip this many frames at start |
| `trimEndFrame` | `int?` | `null` | Stop before end of audio |
| `volume` | `double` | `1.0` | Volume (0.0-1.0) |
| `fadeInFrames` | `int` | `0` | Fade in duration |
| `fadeOutFrames` | `int` | `0` | Fade out duration |
| `loop` | `bool` | `true` | Loop if audio is shorter |
| `child` | `Widget` | `SizedBox.shrink()` | Child widget |

---

## Examples

### Basic Background Music

```dart
BackgroundAudio(
  source: AudioSource.asset('assets/audio/music.mp3'),
  child: MyVideoContent(),
)
```

### With Volume and Fading

```dart
BackgroundAudio(
  source: AudioSource.asset('assets/audio/music.mp3'),
  volume: 0.6,            // 60% volume
  fadeInFrames: 60,       // 2 second fade in at 30fps
  fadeOutFrames: 90,      // 3 second fade out
  child: MyVideoContent(),
)
```

### Skip Intro of Song

```dart
BackgroundAudio(
  source: AudioSource.asset('assets/audio/music.mp3'),
  trimStartFrame: 90,     // Skip first 3 seconds
  volume: 0.7,
  fadeInFrames: 30,
  fadeOutFrames: 60,
  child: MyVideoContent(),
)
```

### From File or URL

```dart
// From file
BackgroundAudio(
  source: AudioSource.file('/path/to/music.mp3'),
  volume: 0.7,
  child: MyVideoContent(),
)

// From URL
BackgroundAudio(
  source: AudioSource.url('https://example.com/music.mp3'),
  volume: 0.7,
  child: MyVideoContent(),
)
```

### Complete VideoComposition Example

```dart
VideoComposition(
  fps: 30,
  durationInFrames: 300,  // 10 seconds
  width: 1920,
  height: 1080,
  child: BackgroundAudio(
    source: AudioSource.asset('assets/audio/ambient.mp3'),
    volume: 0.5,
    fadeInFrames: 45,     // 1.5 second fade in
    fadeOutFrames: 60,    // 2 second fade out
    loop: true,           // Loop if ambient is short
    child: LayerStack(
      children: [
        Layer.background(
          child: GradientBackground(),
        ),
        Layer(
          startFrame: 30,
          fadeInFrames: 20,
          child: VCenter(child: Title()),
        ),
      ],
    ),
  ),
)
```

---

## Comparison with AudioTrack

### BackgroundAudio

```dart
// Simple - auto-detects duration
BackgroundAudio(
  source: AudioSource.asset('assets/audio/music.mp3'),
  volume: 0.7,
  fadeInFrames: 30,
  fadeOutFrames: 60,
  child: Content(),
)
```

### Equivalent AudioTrack

```dart
// Manual - requires duration
AudioTrack(
  source: AudioSource.asset('assets/audio/music.mp3'),
  startFrame: 0,
  durationInFrames: 300,  // Must match video duration
  volume: 0.7,
  fadeInFrames: 30,
  fadeOutFrames: 60,
  loop: true,
)
```

### When to Use Each

| Scenario | Widget |
|----------|--------|
| Single background track for full video | `BackgroundAudio` |
| Music starting at specific frame | `AudioTrack` |
| Sound effect at specific moment | `AudioTrack` |
| Multiple overlapping audio clips | `AudioTrack` |
| Audio synced to visual elements | `AudioTrack` |

---

## Using with Video Widget

The `Video` widget has built-in background music properties that are even simpler:

```dart
Video(
  fps: 30,
  width: 1920,
  height: 1080,
  backgroundMusicAsset: 'assets/audio/music.mp3',
  musicVolume: 0.7,
  musicFadeInFrames: 60,
  musicFadeOutFrames: 90,
  scenes: [...],
)
```

This is equivalent to using `BackgroundAudio` but requires less nesting.

### When to Use Each

| Approach | Use When |
|----------|----------|
| `Video.backgroundMusicAsset` | Using `Video` widget with simple music needs |
| `BackgroundAudio` | Using `VideoComposition` directly |
| `AudioTrack` | Complex audio requirements |

---

## Looping Behavior

By default, `BackgroundAudio` loops (`loop: true`). This means:

- If your audio is shorter than the video, it repeats
- If your audio is longer, it gets cut at video end
- The fade out applies at the video end, not audio end

```dart
// 30-second audio for a 2-minute video
// Audio will loop ~4 times
BackgroundAudio(
  source: AudioSource.asset('assets/audio/short_loop.mp3'),
  loop: true,  // Default
  fadeOutFrames: 60,  // Fade out at video end
  child: Content(),
)
```

---

## Related

- [AudioTrack](audio-track.md) - More control over timing
- [AudioSource](audio-source.md) - Audio file references
- [Video](../core/video.md) - Built-in background music
- [Embedding Audio](../../embedding/audio.md) - Audio guide
