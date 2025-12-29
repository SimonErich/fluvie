# Animated Title Sequences

Create engaging title animations with fades, motion, and effects.

## Problem

You want to create a professional-looking title sequence that fades in, stays visible, then fades out with smooth animations.

## Solution

Use `Layer` with fade transitions and `TimeConsumer` for custom animations.

### Basic Title with Fade

```dart
import 'package:flutter/material.dart';
import 'package:fluvie/fluvie.dart';

final composition = VideoComposition(
  fps: 30,
  durationInFrames: 150, // 5 seconds
  width: 1920,
  height: 1080,
  child: LayerStack(
    children: [
      // Background
      Layer.background(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
            ),
          ),
        ),
      ),

      // Title text with fade
      Layer(
        id: 'title',
        startFrame: 15,
        endFrame: 135,
        fadeInFrames: 30,
        fadeOutFrames: 30,
        child: Center(
          child: Text(
            'Your Title Here',
            style: TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    ],
  ),
);
```

### Title with Motion

Add slide-in and slide-out animations:

```dart
Layer(
  id: 'title',
  startFrame: 15,
  endFrame: 135,
  fadeInFrames: 30,
  fadeOutFrames: 30,
  child: TimeConsumer(
    builder: (context, frame, progress) {
      // Slide in from left during fade in
      double xOffset = 0;
      if (frame < 45) {  // During fade in
        xOffset = -200 * (1 - (frame - 15) / 30);
      }

      // Slide out to right during fade out
      if (frame > 105) {  // During fade out
        xOffset = 200 * ((frame - 105) / 30);
      }

      return Transform.translate(
        offset: Offset(xOffset, 0),
        child: Center(
          child: Text(
            'Your Title Here',
            style: TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
    },
  ),
)
```

### Multi-line Title with Staggered Animation

Animate multiple text lines with delays:

```dart
LayerStack(
  children: [
    // First line
    Layer(
      id: 'title_line1',
      startFrame: 15,
      endFrame: 135,
      fadeInFrames: 20,
      fadeOutFrames: 20,
      child: TimeConsumer(
        builder: (context, frame, progress) {
          return Transform.translate(
            offset: Offset(0, -50),
            child: Center(
              child: Text(
                'Welcome to',
                style: TextStyle(
                  fontSize: 48,
                  color: Colors.white70,
                ),
              ),
            ),
          );
        },
      ),
    ),

    // Second line (delayed)
    Layer(
      id: 'title_line2',
      startFrame: 25,  // 10 frames later
      endFrame: 135,
      fadeInFrames: 20,
      fadeOutFrames: 20,
      child: TimeConsumer(
        builder: (context, frame, progress) {
          return Transform.translate(
            offset: Offset(0, 20),
            child: Center(
              child: Text(
                'Your Amazing Video',
                style: TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          );
        },
      ),
    ),
  ],
)
```

## Expected Output

- Title fades in smoothly over 1 second
- Remains visible for 3 seconds
- Fades out over 1 second
- Optional slide motion for dynamic effect
- Multi-line titles animate with stagger effect

## Variations

### Typewriter Effect

```dart
TimeConsumer(
  builder: (context, frame, progress) {
    final text = 'Your Title Here';
    final visibleChars = (text.length * progress).floor();

    return Center(
      child: Text(
        text.substring(0, visibleChars),
        style: TextStyle(fontSize: 72, color: Colors.white),
      ),
    );
  },
)
```

### Scale Animation

```dart
TimeConsumer(
  builder: (context, frame, progress) {
    // Scale from 0.5x to 1.0x during fade in
    final scale = 0.5 + (0.5 * progress);

    return Transform.scale(
      scale: scale,
      child: Center(
        child: Text(
          'Your Title Here',
          style: TextStyle(fontSize: 72, color: Colors.white),
        ),
      ),
    );
  },
)
```

### Glow Effect

```dart
Center(
  child: Container(
    decoration: BoxDecoration(
      boxShadow: [
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.5),
          blurRadius: 30,
          spreadRadius: 10,
        ),
      ],
    ),
    child: Text(
      'Your Title Here',
      style: TextStyle(
        fontSize: 72,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
  ),
)
```

## Tips

1. **Match fade duration to music**: Use 15-30 frames (0.5-1 second at 30fps)
2. **Use easing curves**: Apply `Curves.easeInOut` for smoother motion
3. **Test different fonts**: Some fonts work better at different sizes
4. **Add shadows**: Improve readability over complex backgrounds
5. **Keep it simple**: Less animation is often more professional

## Related

- [Kinetic Typography](kinetic-typography.md) - More dynamic text animations
- [Crossfade Between Scenes](crossfade.md) - Transition between titles
- [Audio Sync](audio-sync.md) - Time titles to music beats

## Full API Reference

- [`Layer`](../widgets/core-widgets.md#layer)
- [`TimeConsumer`](../widgets/core-widgets.md#timeconsumer)
- [`FadeText`](../widgets/text-widgets.md#fadetext)
