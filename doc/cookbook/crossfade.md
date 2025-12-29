# Crossfade Between Scenes

Smoothly transition between video sequences using crossfade transitions.

## Problem

You want to transition between two scenes with a smooth crossfade effect where one scene fades out while the next fades in.

## Solution

Use `CrossFadeTransition` or overlap `Layer` fade times.

### Using CrossFadeTransition

```dart
import 'package:flutter/material.dart';
import 'package:fluvie/fluvie.dart';

final composition = VideoComposition(
  fps: 30,
  durationInFrames: 180,  // 6 seconds
  width: 1920,
  height: 1080,
  child: VideoSequence(
    children: [
      // Scene 1
      Sequence(
        startFrame: 0,
        durationInFrames: 90,
        child: Container(
          color: Colors.blue,
          child: Center(
            child: Text(
              'Scene 1',
              style: TextStyle(fontSize: 72, color: Colors.white),
            ),
          ),
        ),
      ),

      // Crossfade transition (15 frames = 0.5 seconds)
      CrossFadeTransition(durationInFrames: 15),

      // Scene 2
      Sequence(
        startFrame: 90,
        durationInFrames: 90,
        child: Container(
          color: Colors.purple,
          child: Center(
            child: Text(
              'Scene 2',
              style: TextStyle(fontSize: 72, color: Colors.white),
            ),
          ),
        ),
      ),
    ],
  ),
);
```

### Using Overlapping Layers

Alternative approach with more control:

```dart
VideoComposition(
  fps: 30,
  durationInFrames: 180,
  width: 1920,
  height: 1080,
  child: LayerStack(
    children: [
      // Scene 1
      Layer(
        id: 'scene1',
        startFrame: 0,
        endFrame: 105,  // Overlaps with scene2
        fadeOutFrames: 15,
        child: Container(
          color: Colors.blue,
          child: Center(
            child: Text(
              'Scene 1',
              style: TextStyle(fontSize: 72, color: Colors.white),
            ),
          ),
        ),
      ),

      // Scene 2
      Layer(
        id: 'scene2',
        startFrame: 90,  // Starts before scene1 ends
        endFrame: 180,
        fadeInFrames: 15,
        child: Container(
          color: Colors.purple,
          child: Center(
            child: Text(
              'Scene 2',
              style: TextStyle(fontSize: 72, color: Colors.white),
            ),
          ),
        ),
      ),
    ],
  ),
)
```

## Expected Output

- Scene 1 is fully visible
- Crossfade begins: Scene 1 fades out while Scene 2 fades in
- Crossfade completes: Scene 2 is fully visible
- Duration: 15-30 frames (0.5-1 second)

## Variations

### Multiple Scene Crossfades

```dart
VideoSequence(
  children: [
    Sequence(startFrame: 0, durationInFrames: 90, child: Scene1()),
    CrossFadeTransition(durationInFrames: 20),

    Sequence(startFrame: 90, durationInFrames: 90, child: Scene2()),
    CrossFadeTransition(durationInFrames: 20),

    Sequence(startFrame: 180, durationInFrames: 90, child: Scene3()),
  ],
)
```

### Variable Speed Crossfade

Slower at start, faster at end:

```dart
Layer(
  fadeOutFrames: 30,
  fadeOutCurve: Curves.easeIn,  // Accelerate fade
  // ...
)
```

### Crossfade with Zoom

Combine crossfade with scale animation:

```dart
Layer(
  id: 'scene1',
  startFrame: 0,
  endFrame: 105,
  fadeOutFrames: 15,
  child: TimeConsumer(
    builder: (context, frame, progress) {
      // Zoom out during fade
      final scale = frame > 90 ? 1.0 + ((frame - 90) / 15) * 0.3 : 1.0;

      return Transform.scale(
        scale: scale,
        child: Scene1(),
      );
    },
  ),
)
```

## Tips

1. **Crossfade duration**: 15-30 frames (0.5-1 second) feels natural
2. **Overlap timing**: Scenes should overlap by exactly the fade duration
3. **Layer order**: Later scenes should be on top (higher in LayerStack)
4. **Match motion**: Crossfade works best between scenes with similar composition
5. **Audio crossfade**: Sync audio fade with video crossfade

## Common Pitfalls

❌ **Gap between scenes**: Ensure startFrame overlaps
```dart
// Wrong: Gap between scenes
Layer(endFrame: 90, fadeOutFrames: 15, ...)
Layer(startFrame: 90, fadeInFrames: 15, ...)  // 0-frame overlap!
```

✅ **Correct overlap**:
```dart
// Right: Proper overlap
Layer(endFrame: 105, fadeOutFrames: 15, ...)
Layer(startFrame: 90, fadeInFrames: 15, ...)  // 15-frame overlap
```

## Related

- [Slide Transitions](slide-transitions.md) - Move scenes in/out
- [Zoom Effects](zoom-effects.md) - Zoom during transitions
- [Audio Sync](audio-sync.md) - Time transitions to music

## Full API Reference

- [`CrossFadeTransition`](../widgets/core-widgets.md#crossfadetransition)
- [`Layer`](../widgets/core-widgets.md#layer)
- [`Sequence`](../widgets/core-widgets.md#sequence)
