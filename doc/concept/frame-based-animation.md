# Frame-Based Animation

> **Why frames matter for video and how to think in frames**

Unlike traditional Flutter animations that run on wall-clock time, Fluvie animations are tied to frame numbers. This is essential for producing deterministic, high-quality video output.

## Table of Contents

- [The Problem with Time-Based Animation](#the-problem-with-time-based-animation)
- [Frame-Based Thinking](#frame-based-thinking)
- [Converting Time to Frames](#converting-time-to-frames)
- [Working with Frames](#working-with-frames)
- [Progress Values](#progress-values)

---

## The Problem with Time-Based Animation

Traditional Flutter animations use `Duration` and real-time:

```dart
// Traditional Flutter animation
AnimationController(
  duration: Duration(seconds: 2),
  vsync: this,
)
```

This approach has problems for video:

### 1. Frame Drops

If your device can't render fast enough, frames are skipped. In video, this causes stuttering.

```
Desired: Frame 0, 1, 2, 3, 4, 5, 6...
Reality: Frame 0, 1, 3, 4, 6...  ← Frames 2, 5 dropped!
```

### 2. Non-Deterministic

Running the same animation twice may produce different results based on system performance.

### 3. Variable Frame Rates

Wall-clock time doesn't align with fixed frame rates (24fps, 30fps, 60fps).

---

## Frame-Based Thinking

Fluvie uses frame numbers as the fundamental unit of time:

```dart
// Fluvie animation
AnimatedText.slideUpFade(
  'Hello',
  startFrame: 0,   // Not a Duration!
  duration: 30,    // 30 frames, not seconds
)
```

### Every Frame is Captured

In render mode, Fluvie captures every single frame, regardless of how long it takes to render:

```
Frame 0  → Render → Capture → Encode
Frame 1  → Render → Capture → Encode
Frame 2  → Render → Capture → Encode
...
Frame N  → Render → Capture → Encode
```

No frames are ever skipped, even if a frame takes 5 seconds to render.

### Deterministic Output

The same composition always produces the same video:

```dart
Video(
  fps: 30,
  width: 1920,
  height: 1080,
  scenes: [Scene(durationInFrames: 90, ...)],
)
// Always produces exactly the same 3-second, 90-frame video
```

---

## Converting Time to Frames

Use this formula to convert between time and frames:

```
frames = seconds × fps
seconds = frames ÷ fps
```

### Common Frame Counts at 30fps

| Duration | Frames |
|----------|--------|
| 0.5 seconds | 15 |
| 1 second | 30 |
| 2 seconds | 60 |
| 3 seconds | 90 |
| 5 seconds | 150 |
| 10 seconds | 300 |
| 30 seconds | 900 |
| 1 minute | 1,800 |

### Helper Functions

Create helpers for common conversions:

```dart
/// Convert seconds to frames
int secondsToFrames(double seconds, int fps) => (seconds * fps).round();

/// Convert frames to seconds
double framesToSeconds(int frames, int fps) => frames / fps;

/// Convert milliseconds to frames
int msToFrames(int ms, int fps) => (ms * fps / 1000).round();
```

### Using Time-Like Values

If you prefer thinking in time, create constants:

```dart
// At 30fps
const int fps = 30;
const int oneSecond = 30;     // 1 second = 30 frames
const int halfSecond = 15;    // 0.5 seconds = 15 frames
const int twoSeconds = 60;    // 2 seconds = 60 frames

Scene(
  durationInFrames: 5 * oneSecond,  // 5 seconds
  fadeInFrames: halfSecond,
  children: [
    AnimatedText.slideUpFade(
      'Title',
      duration: oneSecond,
    ),
  ],
)
```

---

## Working with Frames

### TimeConsumer: The Frame Provider

`TimeConsumer` is the core widget for frame-based animation:

```dart
TimeConsumer(
  builder: (context, frame, progress) {
    // frame: current absolute frame number (0, 1, 2, ...)
    // progress: 0.0 to 1.0 through the composition

    return Text('Frame: $frame');
  },
)
```

### Scene-Relative Frames

Within a scene, you often want frame numbers relative to the scene start:

```dart
Scene(
  durationInFrames: 90,
  children: [
    TimeConsumer(
      builder: (context, globalFrame, _) {
        final sceneContext = SceneContext.of(context);
        final localFrame = sceneContext != null
            ? globalFrame - sceneContext.sceneStartFrame
            : globalFrame;

        // localFrame: 0 to 89 within this scene
        return Text('Scene frame: $localFrame');
      },
    ),
  ],
)
```

### Animation Timing

Calculate animation progress based on frames:

```dart
TimeConsumer(
  builder: (context, frame, _) {
    final sceneContext = SceneContext.of(context);
    final localFrame = frame - (sceneContext?.sceneStartFrame ?? 0);

    // Animation from frame 10 to frame 40
    const startFrame = 10;
    const duration = 30;

    final animProgress = ((localFrame - startFrame) / duration).clamp(0.0, 1.0);

    // Apply easing
    final easedProgress = Curves.easeOutCubic.transform(animProgress);

    // Use progress for animation
    final opacity = easedProgress;
    final translateY = 50 * (1 - easedProgress);

    return Transform.translate(
      offset: Offset(0, translateY),
      child: Opacity(
        opacity: opacity,
        child: Text('Animated!'),
      ),
    );
  },
)
```

---

## Progress Values

Many Fluvie widgets use progress values (0.0 to 1.0) that represent animation completion:

### Composition Progress

```dart
TimeConsumer(
  builder: (context, frame, progress) {
    // progress: 0.0 at frame 0, 1.0 at last frame

    final color = Color.lerp(Colors.blue, Colors.red, progress)!;
    return Container(color: color);
  },
)
```

### Scene Progress

```dart
Scene(
  durationInFrames: 90,
  children: [
    VCenter(
      child: TimeConsumer(
        builder: (context, frame, _) {
          final sceneContext = SceneContext.of(context);
          if (sceneContext == null) return SizedBox.shrink();

          final sceneProgress = sceneContext.progress;
          // sceneProgress: 0.0 at scene start, 1.0 at scene end

          return CircularProgressIndicator(value: sceneProgress);
        },
      ),
    ),
  ],
)
```

### Animation Progress

For custom animations:

```dart
// Calculate progress for a specific animation window
double getAnimationProgress({
  required int currentFrame,
  required int startFrame,
  required int duration,
}) {
  if (currentFrame < startFrame) return 0.0;
  if (currentFrame >= startFrame + duration) return 1.0;
  return (currentFrame - startFrame) / duration;
}
```

---

## Practical Examples

### Staggered Animations

Animate children with frame-based delays:

```dart
Scene(
  durationInFrames: 120,
  children: [
    for (var i = 0; i < 5; i++)
      AnimatedText.slideUpFade(
        'Item $i',
        startFrame: i * 10, // Each item starts 10 frames after the previous
        duration: 20,
      ),
  ],
)
```

### Keyframe Animation

Define keyframes at specific frames:

```dart
TimeConsumer(
  builder: (context, frame, _) {
    // Keyframe animation: scale bounces
    final scale = interpolate(
      frame.toDouble(),
      inputRange: [0, 15, 25, 30],
      outputRange: [1.0, 1.3, 0.9, 1.0],
      curve: Curves.easeInOut,
    );

    return Transform.scale(
      scale: scale,
      child: MyWidget(),
    );
  },
)
```

### Looping Animation

Create a loop within a frame range:

```dart
TimeConsumer(
  builder: (context, frame, _) {
    // 30-frame loop
    final loopFrame = frame % 30;
    final loopProgress = loopFrame / 30;

    // Oscillate: 0 → 1 → 0
    final oscillation = (loopProgress * 2 * pi).sin().abs();

    return Transform.translate(
      offset: Offset(0, oscillation * 20),
      child: MyWidget(),
    );
  },
)
```

---

## Frame Rate Considerations

### Choosing a Frame Rate

| fps | Use Case |
|-----|----------|
| 24 | Cinematic, film-like |
| 30 | Standard video, social media |
| 60 | Smooth motion, gaming content |

### Frame Rate Impacts

Higher frame rates mean:
- More frames to render (longer export time)
- Smoother motion
- Larger file sizes
- More granular timing control

```dart
// 30fps: 90 frames = 3 seconds
Video(fps: 30, scenes: [Scene(durationInFrames: 90, ...)])

// 60fps: 180 frames = 3 seconds
Video(fps: 60, scenes: [Scene(durationInFrames: 180, ...)])
```

### Frame Rate and Audio Sync

Audio is also synced to frames. Common audio sync points:

| Event | At 30fps | At 60fps |
|-------|----------|----------|
| Beat at 120 BPM | Every 15 frames | Every 30 frames |
| Beat at 60 BPM | Every 30 frames | Every 60 frames |

---

## Tips for Frame-Based Animation

### 1. Think in Beats, Not Seconds

For music-synced videos, calculate frame timing from BPM:

```dart
int framesPerBeat(int bpm, int fps) => (fps * 60 / bpm).round();

// At 120 BPM, 30fps = 15 frames per beat
final beat = framesPerBeat(120, 30); // 15

Scene(
  durationInFrames: beat * 16, // 16 beats
  children: [
    AnimatedText.slideUpFade('Drop!', startFrame: beat * 4, duration: beat),
  ],
)
```

### 2. Use Named Constants

Make your code readable:

```dart
const fps = 30;
const beat = 15; // At 120 BPM
const bar = beat * 4; // 4 beats = 1 bar

Scene(
  durationInFrames: bar * 4, // 4 bars
  children: [
    AnimatedText('Intro', startFrame: 0, duration: bar),
    AnimatedText('Verse', startFrame: bar, duration: bar * 2),
    AnimatedText('Chorus', startFrame: bar * 3, duration: bar),
  ],
)
```

### 3. Preview at Different Speeds

Use time dilation in preview to check timing:

```dart
// In your preview widget
timeDilation = 0.5; // Half speed for checking fast animations
```

---

## Related Documentation

- [TimeConsumer Widget](../widgets/core/time-consumer.md) - Frame provider
- [Interpolate Function](../animations/interpolate.md) - Keyframe values
- [PropAnimation](../animations/prop-animation.md) - Built-in animations
