# Embedding Audio

> **Adding music and sound effects to Fluvie compositions**

Audio brings your video to life. This guide covers background music, sound effects, volume control, and synchronization.

## Table of Contents

- [Overview](#overview)
- [AudioTrack](#audiotrack)
- [BackgroundAudio](#backgroundaudio)
- [Audio Sources](#audio-sources)
- [Volume and Fading](#volume-and-fading)
- [Timing and Sync](#timing-and-sync)
- [Multiple Audio Tracks](#multiple-audio-tracks)
- [Best Practices](#best-practices)

---

## Overview

Fluvie supports multiple audio tracks that are mixed during rendering:

| Type | Use Case | Added To |
|------|----------|----------|
| `AudioTrack` | Background music, narration | `Video.audioTracks` |
| `BackgroundAudio` | Legacy, simple music | `Video.backgroundMusicAsset` |
| `EmbeddedVideo` audio | Video clip sound | `EmbeddedVideo.volume` |

During rendering, all audio sources are mixed together by FFmpeg.

---

## AudioTrack

The primary way to add audio to your composition.

### Basic Usage

```dart
Video(
  fps: 30,
  width: 1080,
  height: 1920,
  scenes: [...],
  audioTracks: [
    AudioTrack(
      source: AudioSource.asset('assets/music.mp3'),
      volume: 0.8,
    ),
  ],
)
```

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `source` | `AudioSource` | **required** | Audio file source |
| `volume` | `double` | `1.0` | Volume level (0.0 - 1.0) |
| `startFrame` | `int` | `0` | Frame to start playing |
| `durationInFrames` | `int?` | `null` | Duration (null = full length) |
| `trimStart` | `Duration?` | `null` | Skip beginning of audio |
| `trimEnd` | `Duration?` | `null` | Stop at this point |
| `fadeInFrames` | `int` | `0` | Fade in duration |
| `fadeOutFrames` | `int` | `0` | Fade out duration |
| `loop` | `bool` | `false` | Loop audio |

### With Fading

```dart
AudioTrack(
  source: AudioSource.asset('assets/music.mp3'),
  volume: 0.8,
  fadeInFrames: 60,   // 2-second fade in at 30fps
  fadeOutFrames: 90,  // 3-second fade out
)
```

### Trimmed Audio

```dart
AudioTrack(
  source: AudioSource.asset('assets/song.mp3'),
  trimStart: Duration(seconds: 30),  // Skip intro
  trimEnd: Duration(minutes: 2),     // Use only 1:30
  volume: 0.7,
)
```

---

## BackgroundAudio

Legacy convenience for simple background music.

```dart
Video(
  fps: 30,
  width: 1080,
  height: 1920,
  scenes: [...],
  backgroundMusicAsset: 'assets/music.mp3',
  musicVolume: 0.8,
  musicFadeInFrames: 60,
  musicFadeOutFrames: 90,
)
```

---

## Audio Sources

### Asset Audio

Audio files bundled with your app:

```dart
AudioSource.asset('assets/audio/music.mp3')
```

Register in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/audio/
```

### File Audio

Audio from the file system:

```dart
AudioSource.file('/path/to/audio.mp3')
```

### URL Audio

Audio from the web (downloaded during render):

```dart
AudioSource.url('https://example.com/audio.mp3')
```

---

## Volume and Fading

### Static Volume

```dart
AudioTrack(
  source: AudioSource.asset('assets/music.mp3'),
  volume: 0.5,  // 50% volume throughout
)
```

### Fade In

```dart
AudioTrack(
  source: AudioSource.asset('assets/music.mp3'),
  volume: 1.0,
  fadeInFrames: 90,  // 3 seconds at 30fps
  // Volume: 0 → 1.0 over 90 frames
)
```

### Fade Out

```dart
AudioTrack(
  source: AudioSource.asset('assets/music.mp3'),
  volume: 1.0,
  fadeOutFrames: 60,  // 2 seconds at 30fps
  // Volume: 1.0 → 0 over last 60 frames
)
```

### Fade Both

```dart
AudioTrack(
  source: AudioSource.asset('assets/music.mp3'),
  volume: 0.8,
  fadeInFrames: 60,
  fadeOutFrames: 120,
)
```

### Volume Timeline

```
Frame:   0     60    ...    180   240   300
         |-----|------------|-----|-----|
Volume:  0 → 0.8   (steady)   0.8 → 0
         fadeIn              fadeOut
```

---

## Timing and Sync

### Delayed Start

```dart
AudioTrack(
  source: AudioSource.asset('assets/sfx.mp3'),
  startFrame: 90,  // Start at frame 90 (3 seconds at 30fps)
)
```

### Sound Effect at Specific Moment

```dart
Video(
  fps: 30,
  scenes: [
    Scene(
      durationInFrames: 150,
      children: [
        // Explosion animation at frame 60
        AnimatedProp(
          startFrame: 60,
          animation: PropAnimation.zoomIn(),
          child: Image.asset('assets/explosion.png'),
        ),
      ],
    ),
  ],
  audioTracks: [
    // Background music
    AudioTrack(
      source: AudioSource.asset('assets/music.mp3'),
      volume: 0.5,
    ),
    // Explosion sound synced to animation
    AudioTrack(
      source: AudioSource.asset('assets/boom.mp3'),
      startFrame: 60,  // Same as animation start
      volume: 1.0,
    ),
  ],
)
```

### Looping Audio

```dart
// Short ambient loop for long video
AudioTrack(
  source: AudioSource.asset('assets/ambient_loop.mp3'),
  loop: true,
  volume: 0.3,
)
```

---

## Multiple Audio Tracks

### Music + Sound Effects

```dart
Video(
  scenes: [...],
  audioTracks: [
    // Background music (throughout)
    AudioTrack(
      source: AudioSource.asset('assets/music.mp3'),
      volume: 0.6,
      fadeInFrames: 60,
      fadeOutFrames: 90,
    ),

    // Whoosh sound at scene transition (frame 150)
    AudioTrack(
      source: AudioSource.asset('assets/whoosh.mp3'),
      startFrame: 145,  // Slightly before transition
      volume: 0.8,
    ),

    // Celebration sound at reveal (frame 300)
    AudioTrack(
      source: AudioSource.asset('assets/celebration.mp3'),
      startFrame: 300,
      volume: 0.9,
    ),
  ],
)
```

### Layered Music

```dart
audioTracks: [
  // Base track
  AudioTrack(
    source: AudioSource.asset('assets/drums.mp3'),
    volume: 0.7,
  ),

  // Melody layer (enters later)
  AudioTrack(
    source: AudioSource.asset('assets/melody.mp3'),
    startFrame: 90,
    volume: 0.6,
    fadeInFrames: 30,
  ),

  // Synth layer (enters even later)
  AudioTrack(
    source: AudioSource.asset('assets/synth.mp3'),
    startFrame: 180,
    volume: 0.5,
    fadeInFrames: 45,
  ),
]
```

---

## Audio from Videos

Embedded videos can include their audio:

```dart
Scene(
  durationInFrames: 300,
  children: [
    EmbeddedVideo(
      assetPath: 'assets/interview.mp4',
      volume: 1.0,  // Include video's audio
    ),
  ],
)
```

### Ducking Music for Video Audio

Lower music volume when video has important audio:

```dart
Video(
  scenes: [
    // Scene with speaking video
    Scene(
      durationInFrames: 300,
      children: [
        EmbeddedVideo(
          assetPath: 'assets/interview.mp4',
          volume: 1.0,
        ),
      ],
    ),
  ],
  audioTracks: [
    AudioTrack(
      source: AudioSource.asset('assets/music.mp3'),
      volume: 0.2,  // Lower volume so speech is clear
    ),
  ],
)
```

---

## Best Practices

### 1. Use Appropriate Formats

| Format | Pros | Cons |
|--------|------|------|
| MP3 | Universal, small | Lossy |
| AAC/M4A | Better quality, small | Requires codec |
| WAV | Lossless | Very large files |
| OGG | Open, good quality | Less universal |

**Recommended**: MP3 or AAC for music, WAV for critical sound effects.

### 2. Prepare Audio Files

```bash
# Normalize audio levels
ffmpeg -i input.mp3 -af loudnorm output.mp3

# Convert to consistent format
ffmpeg -i input.wav -acodec libmp3lame -q:a 2 output.mp3

# Trim audio externally
ffmpeg -i input.mp3 -ss 00:00:30 -t 00:02:00 -c copy trimmed.mp3
```

### 3. Start Audio Early

Human perception anticipates sound. Start audio slightly before visual:

```dart
// Animation starts at frame 60
AnimatedProp(startFrame: 60, ...)

// Sound starts at frame 57 (0.1 seconds early)
AudioTrack(startFrame: 57, ...)
```

### 4. Fade Everything

Abrupt audio starts/stops are jarring:

```dart
// Always add some fade
AudioTrack(
  source: AudioSource.asset('assets/music.mp3'),
  fadeInFrames: 15,   // At minimum
  fadeOutFrames: 30,
)
```

### 5. Watch Total Volume

Multiple tracks can clip when summed. Keep total under 1.0:

```dart
// 3 tracks at 0.3 each = 0.9 total (safe)
AudioTrack(source: track1, volume: 0.3),
AudioTrack(source: track2, volume: 0.3),
AudioTrack(source: track3, volume: 0.3),
```

### 6. Test Audio Sync

Preview your composition to verify audio timing matches visuals.

---

## Related

- [Sync Anchors](../advanced/sync-anchors.md) - Advanced audio-visual synchronization
- [Videos](videos.md) - Video embedding with audio
- [Performance Tips](../advanced/performance-tips.md)
