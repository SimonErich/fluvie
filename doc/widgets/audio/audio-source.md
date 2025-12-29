# AudioSource

> **Reference to an audio file**

`AudioSource` represents an audio file that can be used with `AudioTrack` or `BackgroundAudio`. It supports Flutter assets, file system paths, and remote URLs.

## Table of Contents

- [Overview](#overview)
- [Factory Constructors](#factory-constructors)
- [Examples](#examples)
- [Best Practices](#best-practices)
- [Related](#related)

---

## Overview

`AudioSource` is an abstract class with factory constructors for different audio sources:

```dart
// From Flutter assets
AudioSource.asset('assets/audio/music.mp3')

// From file system
AudioSource.file('/path/to/music.mp3')

// From URL
AudioSource.url('https://example.com/music.mp3')
```

---

## Factory Constructors

### AudioSource.asset

Load audio from Flutter assets (defined in `pubspec.yaml`):

```dart
AudioSource.asset('assets/audio/background_music.mp3')
```

**Requirements:**
- File must be listed in `pubspec.yaml` under `flutter.assets`
- Path is relative to project root

```yaml
flutter:
  assets:
    - assets/audio/
```

### AudioSource.file

Load audio from the file system:

```dart
AudioSource.file('/absolute/path/to/music.mp3')
AudioSource.file('relative/path/to/music.mp3')
```

**Use cases:**
- User-selected files
- Dynamically downloaded content
- Server-side rendering with local files

### AudioSource.url

Load audio from a remote URL:

```dart
AudioSource.url('https://example.com/audio/music.mp3')
```

**Considerations:**
- Audio is downloaded during rendering
- Requires network access
- Consider caching for repeated renders

---

## Examples

### With AudioTrack

```dart
AudioTrack(
  source: AudioSource.asset('assets/audio/effect.mp3'),
  startFrame: 60,
  durationInFrames: 30,
)
```

### With BackgroundAudio

```dart
BackgroundAudio(
  source: AudioSource.asset('assets/audio/music.mp3'),
  volume: 0.7,
  fadeInFrames: 30,
  child: MyContent(),
)
```

### Multiple Sources

```dart
final backgroundMusic = AudioSource.asset('assets/audio/music.mp3');
final soundEffect1 = AudioSource.asset('assets/audio/whoosh.mp3');
final soundEffect2 = AudioSource.file('/downloads/custom_sound.mp3');
final voiceover = AudioSource.url('https://api.example.com/audio/narration.mp3');

LayerStack(
  children: [
    AudioTrack(
      source: backgroundMusic,
      startFrame: 0,
      durationInFrames: 300,
      volume: 0.5,
    ),
    AudioTrack(
      source: soundEffect1,
      startFrame: 60,
      durationInFrames: 20,
    ),
    AudioTrack(
      source: soundEffect2,
      startFrame: 120,
      durationInFrames: 30,
    ),
    AudioTrack(
      source: voiceover,
      startFrame: 30,
      durationInFrames: 200,
    ),
    // Visual content...
  ],
)
```

### Dynamic Source Selection

```dart
AudioSource getAudioSource(AudioSourceType type, String path) {
  switch (type) {
    case AudioSourceType.asset:
      return AudioSource.asset(path);
    case AudioSourceType.file:
      return AudioSource.file(path);
    case AudioSourceType.url:
      return AudioSource.url(path);
  }
}

// Usage
final source = getAudioSource(config.sourceType, config.path);
```

---

## Supported Formats

FFmpeg handles audio encoding, so most common formats are supported:

| Format | Extension | Notes |
|--------|-----------|-------|
| MP3 | `.mp3` | Most common, widely supported |
| AAC | `.aac`, `.m4a` | Good quality, smaller files |
| WAV | `.wav` | Uncompressed, large files |
| OGG | `.ogg` | Open format |
| FLAC | `.flac` | Lossless compression |

**Recommendation:** Use MP3 for general audio and WAV for sound effects requiring precise timing.

---

## Best Practices

### 1. Organize Audio Assets

```
assets/
├── audio/
│   ├── music/
│   │   ├── background.mp3
│   │   └── outro.mp3
│   └── sfx/
│       ├── whoosh.mp3
│       ├── ding.mp3
│       └── click.mp3
```

### 2. Use Constants for Asset Paths

```dart
class AudioAssets {
  static const backgroundMusic = 'assets/audio/music/background.mp3';
  static const whoosh = 'assets/audio/sfx/whoosh.mp3';
  static const ding = 'assets/audio/sfx/ding.mp3';
  static const click = 'assets/audio/sfx/click.mp3';
}

// Usage
AudioSource.asset(AudioAssets.whoosh)
```

### 3. Predefine Common Sources

```dart
class AudioSources {
  static final backgroundMusic = AudioSource.asset(AudioAssets.backgroundMusic);
  static final whoosh = AudioSource.asset(AudioAssets.whoosh);
  static final ding = AudioSource.asset(AudioAssets.ding);
}

// Usage
AudioTrack(
  source: AudioSources.whoosh,
  startFrame: 60,
  durationInFrames: 20,
)
```

### 4. Handle Missing Audio Gracefully

For file or URL sources, consider the audio might not be available:

```dart
// Check file exists before using
if (await File(audioPath).exists()) {
  return AudioSource.file(audioPath);
}
// Fallback to asset
return AudioSource.asset('assets/audio/default.mp3');
```

---

## Related

- [AudioTrack](audio-track.md) - Using audio sources
- [BackgroundAudio](background-audio.md) - Background music
- [Embedding Audio](../../embedding/audio.md) - Detailed audio guide
