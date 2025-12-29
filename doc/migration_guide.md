# Migration Guide

## Migrating from v0.0.1 to v0.1.0

This guide covers the breaking changes in Fluvie v0.1.0 and how to update your code.

### Widget Renames

The `Clip` family of widgets has been renamed to `Sequence` for clarity:

| v0.0.1 | v0.1.0 |
|--------|--------|
| `Clip` | `Sequence` |
| `VideoClip` | `VideoSequence` |
| `TextClip` | `TextSequence` |
| `ClipConfig` | `SequenceConfig` |

**Before (v0.0.1):**
```dart
Clip(
  startFrame: 0,
  durationInFrames: 60,
  child: Text('Hello'),
)
```

**After (v0.1.0):**
```dart
Sequence(
  startFrame: 0,
  durationInFrames: 60,
  child: Text('Hello'),
)
```

### Audio Time Parameters

Audio timing has changed from milliseconds to frames for consistency:

| v0.0.1 | v0.1.0 |
|--------|--------|
| `trimStartMs` | `trimStartFrame` |
| `trimEndMs` | `trimEndFrame` |

**Before (v0.0.1):**
```dart
AudioTrack(
  source: AudioSource.asset('audio.mp3'),
  startFrame: 0,
  durationInFrames: 300,
  trimStartMs: 1000,  // 1 second
  trimEndMs: 5000,    // 5 seconds
)
```

**After (v0.1.0):**
```dart
AudioTrack(
  source: AudioSource.asset('audio.mp3'),
  startFrame: 0,
  durationInFrames: 300,
  trimStartFrame: 30,   // 1 second at 30fps
  trimEndFrame: 150,    // 5 seconds at 30fps
)
```

**Conversion formula:**
```dart
// Milliseconds to frames
int msToFrames(int ms, int fps) => (ms * fps / 1000).round();

// Frames to milliseconds
int framesToMs(int frames, int fps) => (frames * 1000 / fps).round();
```

### New Layer System

v0.1.0 introduces a powerful `Layer` widget for time-based visibility:

**Before (v0.0.1) - Using Clip for visibility:**
```dart
Stack(
  children: [
    Clip(
      startFrame: 0,
      durationInFrames: 60,
      child: Background(),
    ),
    Clip(
      startFrame: 30,
      durationInFrames: 90,
      child: Content(),
    ),
  ],
)
```

**After (v0.1.0) - Using Layer:**
```dart
LayerStack(
  children: [
    Layer.background(
      fadeInFrames: 15,
      child: Background(),
    ),
    Layer(
      startFrame: 30,
      endFrame: 120,
      fadeInFrames: 15,
      fadeOutFrames: 15,
      child: Content(),
    ),
  ],
)
```

### CrossFadeTransition Now Works

In v0.0.1, `CrossFadeTransition` was a stub. It now properly fades between children:

```dart
CrossFadeTransition(
  startFrame: 60,
  durationInFrames: 30,
  child1: FirstScene(),
  child2: SecondScene(),
  curve: Curves.easeInOut,
)
```

### New Interpolate Function

The `interpolate()` function is now fully implemented with curve support:

```dart
final xPosition = interpolate(
  frame,
  [0, 30, 60],         // keyframes
  [0.0, 200.0, 100.0], // values
  curve: Curves.easeInOut,
  extrapolate: false,
);
```

### Deprecation Timeline

The old widget names are deprecated but still work:

- **v0.1.0**: Deprecated with warnings
- **v0.3.0**: Last version with deprecated APIs
- **v1.0.0**: Deprecated APIs will be removed

### Quick Migration Script

Run this find-and-replace in your codebase:

1. Replace `Clip(` with `Sequence(`
2. Replace `VideoClip(` with `VideoSequence(`
3. Replace `TextClip(` with `TextSequence(`
4. Replace `ClipConfig` with `SequenceConfig`
5. Replace `trimStartMs:` with `trimStartFrame:` (and update values)
6. Replace `trimEndMs:` with `trimEndFrame:` (and update values)

### Need Help?

- Check the [widget reference](widgets.md) for updated API
- See [examples](../example/) for working code
- Open an issue on [GitHub](https://github.com/simonerich/fluvie/issues)
