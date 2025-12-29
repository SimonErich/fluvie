# Fluvie Widget Reference

Complete reference for all Fluvie widgets and their properties.

## Core Widgets

### VideoComposition

The root widget that defines video properties. Must wrap all video content.

```dart
VideoComposition(
  fps: 30,                    // Frame rate
  durationInFrames: 150,      // Total duration in frames
  width: 1920,                // Video width in pixels
  height: 1080,               // Video height in pixels
  child: MyContent(),
)
```

**Properties:**
| Property | Type | Description |
|----------|------|-------------|
| `fps` | `int` | Frame rate (frames per second) |
| `durationInFrames` | `int` | Total video duration in frames |
| `width` | `int` | Video width in pixels |
| `height` | `int` | Video height in pixels |
| `child` | `Widget` | Content to render |

**Static Methods:**
- `VideoComposition.of(context)` - Access composition from descendant widgets

---

### Sequence

A time-bounded content container. Content is visible within the specified frame range.

```dart
Sequence(
  startFrame: 0,
  durationInFrames: 90,
  child: MyContent(),
)
```

**Properties:**
| Property | Type | Description |
|----------|------|-------------|
| `startFrame` | `int` | First frame where content is visible |
| `durationInFrames` | `int` | How many frames content is visible |
| `child` | `Widget` | Content to display |

---

### TimeConsumer

Provides access to the current frame for animations. Rebuilds on every frame.

```dart
TimeConsumer(
  builder: (context, frame, progress) {
    // frame: current frame number (int)
    // progress: 0.0 to 1.0 within parent sequence
    return Opacity(opacity: progress, child: Text('Hello'));
  },
)
```

**Builder Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `context` | `BuildContext` | Build context |
| `frame` | `int` | Current frame number |
| `progress` | `double` | Progress 0.0-1.0 within parent |

---

## Layer System

### Layer

A single layer with time-based visibility and fade transitions.

```dart
Layer(
  id: 'title',
  startFrame: 30,
  endFrame: 120,
  fadeInFrames: 15,
  fadeOutFrames: 15,
  opacity: 1.0,
  blendMode: BlendMode.srcOver,
  zIndex: 0,
  child: TitleWidget(),
)
```

**Properties:**
| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `id` | `String?` | `null` | Optional identifier for debugging |
| `child` | `Widget` | required | Layer content |
| `startFrame` | `int?` | `null` | Frame when layer becomes visible |
| `endFrame` | `int?` | `null` | Frame when layer becomes invisible |
| `fadeInFrames` | `int` | `0` | Duration of fade-in transition |
| `fadeOutFrames` | `int` | `0` | Duration of fade-out transition |
| `opacity` | `double` | `1.0` | Base opacity (0.0-1.0) |
| `blendMode` | `BlendMode` | `srcOver` | Compositing blend mode |
| `enabled` | `bool` | `true` | Whether layer is rendered |
| `zIndex` | `int?` | `null` | Z-ordering (higher = on top) |
| `fadeInCurve` | `Curve` | `easeOut` | Easing for fade-in |
| `fadeOutCurve` | `Curve` | `easeIn` | Easing for fade-out |
| `transform` | `Matrix4?` | `null` | Transform matrix |
| `transformAlignment` | `AlignmentGeometry` | `center` | Transform origin |

**Factory Constructors:**

```dart
// Background layer with zIndex -1000
Layer.background(child: Background())

// Overlay layer with zIndex 1000
Layer.overlay(child: Watermark())
```

---

### LayerStack

Container for Layer widgets with z-index sorting.

```dart
LayerStack(
  children: [
    Layer.background(child: Background()),
    Layer(startFrame: 30, child: Content()),
    Layer.overlay(child: Watermark()),
  ],
)
```

**Properties:**
| Property | Type | Description |
|----------|------|-------------|
| `children` | `List<Widget>` | Layer widgets to stack |

**Behavior:**
- Sorts children by `zIndex` if specified
- Preserves original order for equal z-indices
- Non-Layer widgets are passed through unchanged

---

### AnimatedLayer

A Layer with built-in TimeConsumer for simplified animations.

```dart
AnimatedLayer(
  startFrame: 0,
  endFrame: 60,
  builder: (context, frame, progress) {
    return Transform.scale(
      scale: 1.0 + progress * 0.5,
      child: Text('Growing'),
    );
  },
)
```

---

## Specialized Sequences

### VideoSequence

Embeds an external video file with trimming support.

```dart
VideoSequence(
  assetPath: 'assets/clip.mp4',
  startFrame: 0,
  durationInFrames: 90,
  trimStartFrame: 30,    // Skip first 30 frames of source
  trimDurationInFrames: 90,
)
```

**Properties:**
| Property | Type | Description |
|----------|------|-------------|
| `assetPath` | `String` | Path to video file |
| `startFrame` | `int` | When to start in composition |
| `durationInFrames` | `int` | How long to show |
| `trimStartFrame` | `int` | Source video start offset |
| `trimDurationInFrames` | `int` | Source video duration to use |

---

### TextSequence

Renders styled text within a time range.

```dart
TextSequence(
  text: 'Hello World',
  startFrame: 0,
  durationInFrames: 60,
  style: TextStyle(fontSize: 48, color: Colors.white),
)
```

---

## Audio

### AudioTrack

Adds an audio track to the video.

```dart
AudioTrack(
  source: AudioSource.asset('audio/music.mp3'),
  startFrame: 0,
  durationInFrames: 300,
  trimStartFrame: 0,
  trimEndFrame: 300,
  volume: 0.8,
  fadeInFrames: 30,
  fadeOutFrames: 30,
  loop: false,
)
```

**Properties:**
| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `source` | `AudioSource` | required | Audio source |
| `startFrame` | `int` | required | When audio starts |
| `durationInFrames` | `int` | required | Audio duration |
| `trimStartFrame` | `int` | `0` | Source audio start offset |
| `trimEndFrame` | `int?` | `null` | Source audio end |
| `volume` | `double` | `1.0` | Volume (0.0-1.0) |
| `fadeInFrames` | `int` | `0` | Fade-in duration |
| `fadeOutFrames` | `int` | `0` | Fade-out duration |
| `loop` | `bool` | `false` | Whether to loop |

---

### AudioSource

Defines where audio comes from.

```dart
// From asset
AudioSource.asset('audio/music.mp3')

// From file path
AudioSource.file('/path/to/audio.mp3')

// From URL
AudioSource.url('https://example.com/audio.mp3')
```

---

### BackgroundAudio

Simplified audio for background music spanning the whole video.

```dart
BackgroundAudio(
  source: AudioSource.asset('audio/bg.mp3'),
  volume: 0.5,
)
```

---

## Transitions

### CrossFadeTransition

Smoothly fades between two widgets.

```dart
CrossFadeTransition(
  startFrame: 60,
  durationInFrames: 30,
  child1: FirstWidget(),
  child2: SecondWidget(),
  curve: Curves.easeInOut,
)
```

**Properties:**
| Property | Type | Description |
|----------|------|-------------|
| `startFrame` | `int` | When transition begins |
| `durationInFrames` | `int` | Transition duration |
| `child1` | `Widget` | Widget to fade out |
| `child2` | `Widget` | Widget to fade in |
| `curve` | `Curve` | Animation curve |

---

## Layout

### CollageTemplate

Pre-defined layout templates.

```dart
CollageTemplate.splitScreen(
  children: [
    LeftContent(),
    RightContent(),
  ],
)
```

---

## Utilities

### interpolate

Keyframe-based value interpolation.

```dart
final value = interpolate(
  frame,                     // Current frame
  [0, 30, 60],              // Input keyframes
  [0.0, 100.0, 50.0],       // Output values
  curve: Curves.easeInOut,   // Optional easing
  extrapolate: false,        // Clamp to range
);
```

### lerpValue

Simple two-value interpolation.

```dart
final opacity = lerpValue(
  progress,           // 0.0 to 1.0
  0.0,               // Start value
  1.0,               // End value
  curve: Curves.easeIn,
);
```

---

## Migration from v0.0.1

The following widgets have been renamed:

| Old Name | New Name |
|----------|----------|
| `Clip` | `Sequence` |
| `VideoClip` | `VideoSequence` |
| `TextClip` | `TextSequence` |

Audio time parameters now use frames instead of milliseconds:

| Old Parameter | New Parameter |
|---------------|---------------|
| `trimStartMs` | `trimStartFrame` |
| `trimEndMs` | `trimEndFrame` |
