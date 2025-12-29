# Audio Widgets

Audio widgets in Fluvie allow you to add music, sound effects, and audio-reactive animations to your video compositions.

## Overview

Fluvie provides several ways to work with audio:

1. **AudioTrack** - Add individual audio clips with precise timing
2. **BackgroundAudio** - Add background music spanning the full video
3. **AudioSource** - Reference audio from assets, files, or URLs
4. **AudioReactive** - Create visuals that respond to audio data

---

## Widget Reference

| Widget | Description | Use Case |
|--------|-------------|----------|
| [AudioTrack](audio-track.md) | Individual audio clip with timing | Sound effects, synced music |
| [AudioSource](audio-source.md) | Audio file reference | All audio widgets |
| [BackgroundAudio](background-audio.md) | Full-duration background music | Background music |
| [AudioReactive](audio-reactive.md) | Audio-responsive animations | Beat visualization, audio sync |

---

## Quick Examples

### Background Music

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

### Sound Effect at Specific Frame

```dart
AudioTrack(
  source: AudioSource.asset('assets/audio/whoosh.mp3'),
  startFrame: 60,      // Play at frame 60
  durationInFrames: 30,
  volume: 0.8,
)
```

### Audio Sources

```dart
// From Flutter assets
AudioSource.asset('assets/audio/music.mp3')

// From file system
AudioSource.file('/path/to/music.mp3')

// From URL
AudioSource.url('https://example.com/music.mp3')
```

### Audio-Reactive Visualization

```dart
AudioReactive(
  provider: myAudioProvider,
  child: TimeConsumer(
    builder: (context, frame, _) {
      final audioData = AudioReactive.of(context);
      final beatStrength = audioData?.provider.getBeatStrengthAt(frame) ?? 0;

      return Transform.scale(
        scale: 1.0 + beatStrength * 0.2,
        child: Circle(),
      );
    },
  ),
)
```

---

## Audio Timing

All audio timing in Fluvie is frame-based for consistency with video:

```dart
// At 30fps:
// 30 frames = 1 second
// 90 frames = 3 seconds

AudioTrack(
  source: AudioSource.asset('assets/sfx.mp3'),
  startFrame: 90,        // Start at 3 seconds
  durationInFrames: 60,  // Play for 2 seconds
  fadeInFrames: 15,      // 0.5 second fade in
  fadeOutFrames: 30,     // 1 second fade out
)
```

---

## Using with Video Widget

The `Video` widget provides convenient background music properties:

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

For more complex audio needs, use `AudioTrack` directly:

```dart
Scene(
  durationInFrames: 300,
  children: [
    // Visual content
    VCenter(child: Content()),

    // Sound effect at frame 60
    AudioTrack(
      source: AudioSource.asset('assets/audio/ding.mp3'),
      startFrame: 60,
      durationInFrames: 30,
    ),
  ],
)
```

---

## Related

- [Embedding Audio](../../embedding/audio.md) - Detailed audio embedding guide
- [Sync Anchors](../../advanced/sync-anchors.md) - Advanced audio sync
- [Video](../core/video.md) - Background music properties
