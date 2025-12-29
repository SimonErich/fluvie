# TimeConsumer

> **The fundamental frame-based animation driver**

`TimeConsumer` is the core widget for creating frame-based animations in Fluvie. It rebuilds on every frame, providing the current frame number and progress value to its builder function.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Examples](#examples)
- [Frame vs Progress](#frame-vs-progress)
- [Scene-Relative Frames](#scene-relative-frames)
- [Performance Tips](#performance-tips)
- [Related](#related)

---

## Overview

`TimeConsumer` listens to frame changes and rebuilds its child with updated timing information. This is how you create custom animations that respond to the video timeline.

```dart
TimeConsumer(
  builder: (context, frame, progress) {
    // frame: current frame number (0, 1, 2, ...)
    // progress: 0.0 at start, 1.0 at end

    return Opacity(
      opacity: progress,
      child: Text('Frame: $frame'),
    );
  },
)
```

### When to Use

Use `TimeConsumer` when:
- Creating custom animations not covered by `AnimatedProp`
- Needing direct access to frame numbers
- Building complex, multi-property animations
- Creating procedural effects

Use `AnimatedProp` or `AnimatedText` instead when:
- Using standard animation patterns (fade, slide, scale)
- Simpler code is preferred

---

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `builder` | `Widget Function(BuildContext, int frame, double progress)` | **required** | Builder function called every frame |

### Builder Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `context` | `BuildContext` | Standard Flutter context |
| `frame` | `int` | Current absolute frame number |
| `progress` | `double` | 0.0-1.0 progress through composition |

---

## Examples

### Basic Fade Animation

```dart
TimeConsumer(
  builder: (context, frame, progress) {
    return Opacity(
      opacity: progress, // Fades in as video progresses
      child: Text('Fading in...'),
    );
  },
)
```

### Color Animation

```dart
TimeConsumer(
  builder: (context, frame, progress) {
    final color = Color.lerp(
      Colors.blue,
      Colors.red,
      progress,
    )!;

    return Container(
      color: color,
      child: Center(child: Text('Color shift')),
    );
  },
)
```

### Position Animation

```dart
TimeConsumer(
  builder: (context, frame, progress) {
    // Move from left to right
    final x = 100 + (progress * 500);

    return Positioned(
      left: x,
      top: 100,
      child: CircleWidget(),
    );
  },
)
```

### Complex Multi-Property Animation

```dart
TimeConsumer(
  builder: (context, frame, progress) {
    // Eased progress
    final easedProgress = Curves.easeOutCubic.transform(progress);

    // Multiple animated properties
    final opacity = easedProgress;
    final scale = 0.5 + (0.5 * easedProgress);
    final translateY = 50 * (1 - easedProgress);

    return Transform.translate(
      offset: Offset(0, translateY),
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: opacity,
          child: MyWidget(),
        ),
      ),
    );
  },
)
```

### Frame-Based Logic

```dart
TimeConsumer(
  builder: (context, frame, _) {
    // Different content at different frames
    if (frame < 30) {
      return Text('Loading...');
    } else if (frame < 90) {
      return Text('Content');
    } else {
      return Text('Finished');
    }
  },
)
```

### Looping Animation

```dart
TimeConsumer(
  builder: (context, frame, _) {
    // 60-frame loop (2 seconds at 30fps)
    final loopFrame = frame % 60;
    final loopProgress = loopFrame / 60;

    // Oscillate: 0 → 1 → 0
    final oscillation = sin(loopProgress * 2 * pi);

    return Transform.translate(
      offset: Offset(0, oscillation * 20),
      child: BouncingWidget(),
    );
  },
)
```

---

## Frame vs Progress

### Frame Number

The `frame` parameter is the absolute frame number from the start of the composition:

```dart
// At 30fps:
// frame 0 = 0.0 seconds
// frame 30 = 1.0 seconds
// frame 90 = 3.0 seconds

TimeConsumer(
  builder: (context, frame, _) {
    final seconds = frame / 30;
    return Text('Time: ${seconds.toStringAsFixed(1)}s');
  },
)
```

### Progress Value

The `progress` parameter is normalized 0.0-1.0 through the entire composition:

```dart
// progress 0.0 = start of video
// progress 0.5 = middle of video
// progress 1.0 = end of video

TimeConsumer(
  builder: (context, _, progress) {
    final percentage = (progress * 100).round();
    return Text('Progress: $percentage%');
  },
)
```

---

## Scene-Relative Frames

When inside a `Scene`, you often want frame numbers relative to the scene start:

```dart
Scene(
  durationInFrames: 120,
  children: [
    TimeConsumer(
      builder: (context, globalFrame, _) {
        // Get scene context
        final sceneContext = SceneContext.of(context);

        // Calculate local frame (0 to 119 within this scene)
        final localFrame = sceneContext != null
            ? globalFrame - sceneContext.sceneStartFrame
            : globalFrame;

        // Get scene progress (0.0 to 1.0 within this scene)
        final sceneProgress = sceneContext?.progress ?? 0.0;

        return AnimatedWidget(
          localFrame: localFrame,
          progress: sceneProgress,
        );
      },
    ),
  ],
)
```

### Helper for Local Frames

Create a helper widget for common patterns:

```dart
class SceneTimeConsumer extends StatelessWidget {
  final Widget Function(BuildContext, int localFrame, double sceneProgress) builder;

  const SceneTimeConsumer({required this.builder});

  @override
  Widget build(BuildContext context) {
    return TimeConsumer(
      builder: (context, globalFrame, _) {
        final sceneContext = SceneContext.of(context);
        final localFrame = sceneContext != null
            ? globalFrame - sceneContext.sceneStartFrame
            : globalFrame;
        final sceneProgress = sceneContext?.progress ?? 0.0;

        return builder(context, localFrame, sceneProgress);
      },
    );
  }
}

// Usage
SceneTimeConsumer(
  builder: (context, localFrame, progress) {
    // localFrame is now 0 to sceneLength-1
    return MyAnimatedWidget(frame: localFrame);
  },
)
```

---

## Animation Patterns

### Delayed Start

```dart
TimeConsumer(
  builder: (context, frame, _) {
    final sceneContext = SceneContext.of(context);
    final localFrame = frame - (sceneContext?.sceneStartFrame ?? 0);

    // Start at frame 30, animate for 45 frames
    const startFrame = 30;
    const duration = 45;

    final progress = ((localFrame - startFrame) / duration).clamp(0.0, 1.0);
    final easedProgress = Curves.easeOutCubic.transform(progress);

    return Opacity(
      opacity: easedProgress,
      child: Content(),
    );
  },
)
```

### Multiple Phases

```dart
TimeConsumer(
  builder: (context, frame, _) {
    final sceneContext = SceneContext.of(context);
    final localFrame = frame - (sceneContext?.sceneStartFrame ?? 0);

    // Phase 1: Frames 0-30 - Fade in
    // Phase 2: Frames 30-90 - Visible
    // Phase 3: Frames 90-120 - Fade out

    double opacity;
    if (localFrame < 30) {
      opacity = localFrame / 30;
    } else if (localFrame < 90) {
      opacity = 1.0;
    } else {
      opacity = 1.0 - ((localFrame - 90) / 30);
    }

    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Content(),
    );
  },
)
```

### Keyframe Animation

```dart
TimeConsumer(
  builder: (context, frame, _) {
    final sceneContext = SceneContext.of(context);
    final localFrame = frame - (sceneContext?.sceneStartFrame ?? 0);

    // Use interpolate for keyframes
    final scale = interpolate(
      localFrame.toDouble(),
      inputRange: [0, 15, 25, 30],
      outputRange: [1.0, 1.3, 0.9, 1.0],
      curve: Curves.easeInOut,
    );

    return Transform.scale(
      scale: scale,
      child: Content(),
    );
  },
)
```

---

## Performance Tips

### 1. Minimize Rebuilds

Only rebuild what changes:

```dart
// Bad: Rebuilds entire complex widget tree every frame
TimeConsumer(
  builder: (context, frame, progress) {
    return ComplexWidget(
      opacity: progress, // Only this changes
      child: VeryExpensiveWidget(), // This doesn't change
    );
  },
)

// Good: Only rebuild the changing part
Stack(
  children: [
    const VeryExpensiveWidget(), // Never rebuilds
    TimeConsumer(
      builder: (context, frame, progress) {
        return Opacity(
          opacity: progress,
          child: const SizedBox(), // Minimal widget
        );
      },
    ),
  ],
)
```

### 2. Cache Expensive Calculations

```dart
TimeConsumer(
  builder: (context, frame, _) {
    // Bad: Recalculates every frame
    final expensiveValue = calculateExpensiveThing();

    // Good: Only calculate when frame changes significantly
    final keyFrame = frame ~/ 10; // Only recalc every 10 frames

    return CachedBuilder(
      key: keyFrame,
      builder: () => calculateExpensiveThing(),
    );
  },
)
```

### 3. Use AnimatedProp for Simple Animations

```dart
// Instead of this:
TimeConsumer(
  builder: (context, frame, _) {
    final progress = ((frame - 30) / 45).clamp(0.0, 1.0);
    return Opacity(
      opacity: progress,
      child: Text('Hello'),
    );
  },
)

// Use this:
AnimatedProp(
  startFrame: 30,
  duration: 45,
  animation: PropAnimation.fadeIn(),
  child: Text('Hello'),
)
```

---

## Related

- [AnimatedProp](../../animations/prop-animation.md) - Pre-built animations
- [AnimatedText](../text/animated-text.md) - Text-specific animations
- [interpolate](../../animations/interpolate.md) - Keyframe interpolation
- [Frame-Based Animation](../../concept/frame-based-animation.md) - Concepts
