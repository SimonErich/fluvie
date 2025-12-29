# Video

> **High-level scene-based video composition**

The `Video` widget is the recommended entry point for creating Fluvie videos. It provides a declarative, scene-based API that handles timing, transitions, and audio automatically.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Examples](#examples)
- [Scene Management](#scene-management)
- [Audio](#audio)
- [Related](#related)

---

## Overview

`Video` is the root widget of the declarative API. It manages:

- **Scenes** - Time-bounded sections of your video
- **Transitions** - Effects between scenes
- **Background music** - Audio that spans the entire video
- **Encoding settings** - Output quality and format

```dart
import 'package:fluvie/declarative.dart';

Video(
  fps: 30,
  width: 1920,
  height: 1080,
  scenes: [
    Scene(durationInFrames: 90, children: [...]),
    Scene(durationInFrames: 60, children: [...]),
  ],
)
```

### When to Use

Use `Video` when:
- Building scene-based compositions
- Using the declarative API
- Creating Spotify Wrapped-style videos
- Prototyping quickly

Use `VideoComposition` instead when:
- You need low-level frame control
- Building custom render pipelines
- Integrating with existing state management

---

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `fps` | `int` | **required** | Frames per second |
| `width` | `int` | **required** | Output width in pixels |
| `height` | `int` | **required** | Output height in pixels |
| `scenes` | `List<Scene>` | **required** | List of scenes in order |
| `encoding` | `EncodingConfig?` | `null` | Quality and format settings |
| `defaultTransition` | `SceneTransition?` | `null` | Transition between all scenes |
| `backgroundMusicAsset` | `String?` | `null` | Asset path for background music |
| `backgroundMusicFile` | `String?` | `null` | File path for background music |
| `backgroundMusicUrl` | `String?` | `null` | URL for background music |
| `musicVolume` | `double` | `1.0` | Background music volume (0.0-1.0) |
| `musicFadeInFrames` | `int` | `0` | Frames to fade in music |
| `musicFadeOutFrames` | `int` | `0` | Frames to fade out music |
| `controller` | `RenderController?` | `null` | Controller for playback control |

---

## Examples

### Basic Video

```dart
Video(
  fps: 30,
  width: 1920,
  height: 1080,
  scenes: [
    Scene(
      durationInFrames: 90, // 3 seconds
      background: Background.solid(Colors.blue),
      children: [
        VCenter(
          child: Text('Hello, World!'),
        ),
      ],
    ),
  ],
)
```

### Multiple Scenes with Transitions

```dart
Video(
  fps: 30,
  width: 1920,
  height: 1080,
  defaultTransition: const SceneTransition.crossFade(durationInFrames: 15),
  scenes: [
    Scene(
      durationInFrames: 90,
      background: Background.solid(Colors.purple),
      children: [
        VCenter(child: Text('Scene 1')),
      ],
    ),
    Scene(
      durationInFrames: 60,
      background: Background.solid(Colors.blue),
      children: [
        VCenter(child: Text('Scene 2')),
      ],
    ),
    Scene(
      durationInFrames: 90,
      background: Background.solid(Colors.teal),
      children: [
        VCenter(child: Text('Scene 3')),
      ],
    ),
  ],
)
```

### With Background Music

```dart
Video(
  fps: 30,
  width: 1920,
  height: 1080,
  backgroundMusicAsset: 'assets/audio/music.mp3',
  musicVolume: 0.7,
  musicFadeInFrames: 60,   // 2 second fade in
  musicFadeOutFrames: 90,  // 3 second fade out
  scenes: [
    Scene(durationInFrames: 300, children: [...]),
    Scene(durationInFrames: 300, children: [...]),
  ],
)
```

### With Encoding Settings

```dart
Video(
  fps: 30,
  width: 1920,
  height: 1080,
  encoding: const EncodingConfig(
    quality: RenderQuality.high,
    frameFormat: FrameFormat.rawRgba,
    debugFrameOutputPath: 'tmp/debug_frames',
  ),
  scenes: [...],
)
```

### Different Aspect Ratios

```dart
// Vertical (9:16) - TikTok/Stories
Video(
  fps: 30,
  width: 1080,
  height: 1920,
  scenes: [...],
)

// Square (1:1) - Instagram
Video(
  fps: 30,
  width: 1080,
  height: 1080,
  scenes: [...],
)

// Widescreen (21:9) - Cinematic
Video(
  fps: 24,  // Film frame rate
  width: 2560,
  height: 1080,
  scenes: [...],
)
```

---

## Scene Management

### Total Duration

The total video duration is the sum of all scene lengths:

```dart
Video(
  fps: 30,
  scenes: [
    Scene(durationInFrames: 90),  // 3 seconds
    Scene(durationInFrames: 60),  // 2 seconds
    Scene(durationInFrames: 150), // 5 seconds
  ],
)
// Total: 300 frames = 10 seconds
```

### Scene Transitions

Transitions overlap scenes. The transition duration comes from the end of the previous scene:

```dart
Video(
  fps: 30,
  defaultTransition: const SceneTransition.crossFade(durationInFrames: 30),
  scenes: [
    Scene(durationInFrames: 90),  // Frames 0-89
    Scene(durationInFrames: 60),  // Starts at frame 60 (30 frame transition)
    Scene(durationInFrames: 90),  // Starts at frame 90 (30 frame transition)
  ],
)
```

### Per-Scene Transitions

Override the default for specific scenes:

```dart
Scene(
  durationInFrames: 90,
  transitionIn: const SceneTransition.slideUp(durationInFrames: 20),
  transitionOut: const SceneTransition.crossFade(durationInFrames: 15),
  children: [...],
)
```

---

## Audio

### Background Music Options

Three ways to provide background music:

```dart
// From Flutter assets
Video(
  backgroundMusicAsset: 'assets/audio/music.mp3',
  ...
)

// From file system
Video(
  backgroundMusicFile: '/path/to/music.mp3',
  ...
)

// From URL
Video(
  backgroundMusicUrl: 'https://example.com/music.mp3',
  ...
)
```

### Audio Fading

```dart
Video(
  backgroundMusicAsset: 'assets/audio/music.mp3',
  musicVolume: 0.8,
  musicFadeInFrames: 60,   // Fade in over first 2 seconds
  musicFadeOutFrames: 90,  // Fade out over last 3 seconds
  ...
)
```

### Additional Audio Tracks

Use `AudioTrack` within scenes for additional audio:

```dart
Scene(
  durationInFrames: 300,
  children: [
    AudioTrack(
      source: AudioSource.asset('assets/audio/effect.mp3'),
      startFrame: 60,
      durationInFrames: 30,
      volume: 0.5,
      child: const SizedBox.shrink(),
    ),
    // Other content...
  ],
)
```

---

## Playback Control

### Using RenderController

```dart
class MyVideoPlayer extends StatefulWidget {
  @override
  State<MyVideoPlayer> createState() => _MyVideoPlayerState();
}

class _MyVideoPlayerState extends State<MyVideoPlayer> {
  final _controller = RenderController();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Video(
            controller: _controller,
            fps: 30,
            width: 1920,
            height: 1080,
            scenes: [...],
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.play_arrow),
              onPressed: () => _controller.play(),
            ),
            IconButton(
              icon: Icon(Icons.pause),
              onPressed: () => _controller.pause(),
            ),
            Slider(
              value: _controller.currentFrame.toDouble(),
              max: _controller.totalFrames.toDouble(),
              onChanged: (value) => _controller.seekTo(value.toInt()),
            ),
          ],
        ),
      ],
    );
  }
}
```

---

## Related

- [VideoComposition](video-composition.md) - Low-level composition
- [Scene](scene.md) - Scene widget reference
- [SceneTransition](../../effects/transitions.md) - Transition types
- [EncodingConfig](../../advanced/encoding-settings.md) - Export settings
- [BackgroundAudio](../audio/background-audio.md) - Alternative audio approach
