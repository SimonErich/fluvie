# AudioTrack

> **Individual audio clip with precise timing control**

`AudioTrack` attaches an audio clip to the video timeline with full control over timing, volume, fading, and trimming. All time values are in frames for consistency with the video timeline.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Constructors](#constructors)
- [Examples](#examples)
- [Sync Anchors](#sync-anchors)
- [Related](#related)

---

## Overview

`AudioTrack` is the primary widget for adding audio to your video:

```dart
AudioTrack(
  source: AudioSource.asset('assets/audio/music.mp3'),
  startFrame: 0,
  durationInFrames: 300,
  fadeInFrames: 30,
  fadeOutFrames: 30,
  volume: 0.8,
)
```

### When to Use

Use `AudioTrack` when you need:
- Sound effects at specific frames
- Music that starts/stops at precise moments
- Audio with trimming (skip intro, cut early)
- Synced audio with visual elements

Use `BackgroundAudio` instead for simple background music spanning the full video.

---

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `source` | `AudioSource` | **required** | The audio file to play |
| `startFrame` | `int` | **required** | Frame to start playback |
| `durationInFrames` | `int` | **required** | How long to play (frames) |
| `trimStartFrame` | `int` | `0` | Skip this many frames at start |
| `trimEndFrame` | `int?` | `null` | Stop this many frames before end |
| `volume` | `double` | `1.0` | Volume (0.0-1.0) |
| `fadeInFrames` | `int` | `0` | Fade in duration |
| `fadeOutFrames` | `int` | `0` | Fade out duration |
| `loop` | `bool` | `false` | Loop if shorter than duration |
| `sync` | `AudioSyncConfig?` | `null` | Sync configuration |
| `child` | `Widget` | `SizedBox.shrink()` | Optional child widget |

---

## Constructors

### Default Constructor

Full control over all timing:

```dart
AudioTrack(
  source: AudioSource.asset('assets/audio/effect.mp3'),
  startFrame: 60,
  durationInFrames: 45,
)
```

### AudioTrack.syncStart

Sync audio start to a `SyncAnchor`:

```dart
AudioTrack.syncStart(
  source: AudioSource.asset('assets/audio/intro.mp3'),
  syncWithAnchor: 'intro_text',
  startOffset: -15,  // Start 15 frames before anchor
  durationInFrames: 150,
)
```

### AudioTrack.syncRange

Sync both start and end to anchors:

```dart
AudioTrack.syncRange(
  source: AudioSource.asset('assets/audio/scene_music.mp3'),
  syncStartWithAnchor: 'scene_start',
  syncEndWithAnchor: 'scene_end',
  startOffset: 0,
  endOffset: 30,  // Extend 30 frames past end for fade out
  behavior: SyncBehavior.loopToMatch,
)
```

---

## Examples

### Basic Sound Effect

```dart
AudioTrack(
  source: AudioSource.asset('assets/audio/whoosh.mp3'),
  startFrame: 60,        // Play at frame 60 (2 seconds at 30fps)
  durationInFrames: 30,  // Play for 1 second
  volume: 0.8,
)
```

### Music with Fading

```dart
AudioTrack(
  source: AudioSource.asset('assets/audio/music.mp3'),
  startFrame: 0,
  durationInFrames: 300,
  fadeInFrames: 30,   // 1 second fade in
  fadeOutFrames: 60,  // 2 second fade out
  volume: 0.7,
)
```

### Trimmed Audio

Skip the intro and cut before the end:

```dart
AudioTrack(
  source: AudioSource.asset('assets/audio/song.mp3'),
  startFrame: 0,
  durationInFrames: 300,
  trimStartFrame: 90,   // Skip first 3 seconds of audio
  trimEndFrame: 150,    // Stop 5 seconds before audio ends
)
```

### Looping Audio

Loop a short clip to fill the duration:

```dart
AudioTrack(
  source: AudioSource.asset('assets/audio/loop.mp3'),
  startFrame: 0,
  durationInFrames: 600,  // 20 seconds
  loop: true,             // Loop if audio is shorter
)
```

### Multiple Audio Tracks

```dart
LayerStack(
  children: [
    // Background music
    AudioTrack(
      source: AudioSource.asset('assets/audio/music.mp3'),
      startFrame: 0,
      durationInFrames: 300,
      volume: 0.5,
      fadeInFrames: 30,
      fadeOutFrames: 60,
    ),

    // Sound effect at specific moment
    AudioTrack(
      source: AudioSource.asset('assets/audio/ding.mp3'),
      startFrame: 90,       // At "reveal" moment
      durationInFrames: 30,
      volume: 0.8,
    ),

    // Another sound effect
    AudioTrack(
      source: AudioSource.asset('assets/audio/whoosh.mp3'),
      startFrame: 150,      // At transition
      durationInFrames: 20,
      volume: 0.6,
    ),

    // Visual content
    VCenter(child: Content()),
  ],
)
```

### In a Scene

```dart
Scene(
  durationInFrames: 180,
  background: Background.solid(Colors.black),
  children: [
    // Title appears with sound
    VPositioned(
      left: 0,
      right: 0,
      top: 200,
      startFrame: 30,
      fadeInFrames: 15,
      child: Text('Your 2024', style: titleStyle),
    ),

    // Sound when title appears
    AudioTrack(
      source: AudioSource.asset('assets/audio/reveal.mp3'),
      startFrame: 25,  // Slightly before visual
      durationInFrames: 45,
      volume: 0.7,
    ),
  ],
)
```

---

## Sync Anchors

Audio tracks can be synced to visual elements using `SyncAnchor`:

### Visual Element with Anchor

```dart
SyncAnchor(
  id: 'title_appear',
  child: VPositioned(
    startFrame: 30,
    fadeInFrames: 15,
    child: Text('Title'),
  ),
)
```

### Audio Synced to Anchor

```dart
AudioTrack.syncStart(
  source: AudioSource.asset('assets/audio/reveal.mp3'),
  syncWithAnchor: 'title_appear',
  startOffset: -5,  // Start 5 frames before title appears
  durationInFrames: 45,
)
```

### Sync Behavior Options

| Behavior | Description |
|----------|-------------|
| `SyncBehavior.stopWhenEnds` | Stop when audio naturally ends |
| `SyncBehavior.loopToMatch` | Loop to fill the synced duration |

```dart
AudioTrack.syncRange(
  source: AudioSource.asset('assets/audio/ambient.mp3'),
  syncStartWithAnchor: 'scene_start',
  syncEndWithAnchor: 'scene_end',
  behavior: SyncBehavior.loopToMatch,  // Loop ambient sound
)
```

---

## Frame Calculations

### Converting Time to Frames

```dart
// At 30fps:
// seconds * fps = frames

final fps = 30;
final seconds = 5;
final frames = seconds * fps;  // 150 frames

AudioTrack(
  source: source,
  startFrame: 2 * fps,        // Start at 2 seconds
  durationInFrames: 5 * fps,  // Play for 5 seconds
)
```

### Trim Example

```dart
// Skip first 10 seconds of a song, play for 30 seconds
AudioTrack(
  source: AudioSource.asset('assets/audio/song.mp3'),
  startFrame: 0,
  durationInFrames: 30 * 30,     // 30 seconds at 30fps = 900 frames
  trimStartFrame: 10 * 30,        // Skip first 10 seconds = 300 frames
)
```

---

## Related

- [AudioSource](audio-source.md) - Audio file references
- [BackgroundAudio](background-audio.md) - Full-video background music
- [SyncAnchor](../../advanced/sync-anchors.md) - Audio-visual sync
- [Embedding Audio](../../embedding/audio.md) - Audio embedding guide
