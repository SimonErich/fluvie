# TimeConsumer Guide

TimeConsumer is the core frame-based animation primitive in Fluvie. While most users will use the higher-level declarative widgets like `AnimatedProp`, `FrameAnimatedPositioned`, and `Stagger`, TimeConsumer provides direct access to the frame-based timeline for power users who need complete control.

## When to Use TimeConsumer

Use TimeConsumer when you need:

- **Custom animation curves** not available in PropAnimation
- **Complex multi-property animations** with interdependent values
- **Physics-based animations** that depend on current state
- **Procedural animations** like particles or generative graphics
- **Frame-perfect synchronization** with audio or video

For simpler animations, prefer the declarative alternatives:

| Task | Recommended Widget |
|------|-------------------|
| Fade in/out | `AnimatedProp.fadeIn()` |
| Slide animations | `AnimatedProp.slideUp()` |
| Entry/exit on positioned elements | `FrameAnimatedPositioned` |
| Staggered child animations | `Stagger` |
| Combined animations | `AnimatedProp` with `PropAnimation.combine()` |

## Basic Usage

```dart
TimeConsumer(
  builder: (context, frame, progress) {
    // frame: Current frame number (0 to durationInFrames-1)
    // progress: Normalized progress 0.0 to 1.0

    return Opacity(
      opacity: progress,
      child: Text('Fading in...'),
    );
  },
)
```

## Understanding Frame vs Progress

- **frame**: The absolute frame number in the composition timeline (integer)
- **progress**: The normalized progress from 0.0 to 1.0 across the entire composition

```dart
// Example: 90-frame composition at 30fps = 3 seconds
// At frame 45:
//   frame = 45
//   progress = 0.5 (halfway through)
```

## Calculating Local Progress

Often you want an animation to run within a specific frame range:

```dart
TimeConsumer(
  builder: (context, frame, _) {
    const startFrame = 30;
    const duration = 60;
    const endFrame = startFrame + duration;

    // Calculate local progress (0.0 to 1.0) for this animation
    double localProgress;
    if (frame < startFrame) {
      localProgress = 0.0;
    } else if (frame >= endFrame) {
      localProgress = 1.0;
    } else {
      localProgress = (frame - startFrame) / duration;
    }

    // Apply easing curve
    final easedProgress = Curves.easeOutCubic.transform(localProgress);

    // Use the progress
    return Transform.translate(
      offset: Offset(0, 100 * (1 - easedProgress)),
      child: child,
    );
  },
)
```

## Integration with AnimationContext

When TimeConsumer is inside an `AnimatedPositioned` or other context-providing widget, you can access parent timing information:

```dart
TimeConsumer(
  builder: (context, frame, _) {
    final animContext = AnimationContext.of(context);

    if (animContext != null) {
      // Get the frame when parent's entry animation completes
      final parentEntryComplete = animContext.entryCompleteFrame;

      // Calculate timing relative to parent
      final effectiveStart = animContext.effectiveStartFrame(
        offsetFrames: 10,  // Start 10 frames after parent entry
        afterParentEntry: true,
      );
    }

    // ... animation logic
  },
)
```

## Common Patterns

### Ping-Pong Animation

```dart
TimeConsumer(
  builder: (context, frame, _) {
    const duration = 30;

    // Create a ping-pong effect
    final cycle = (frame % (duration * 2));
    double progress;
    if (cycle < duration) {
      progress = cycle / duration;
    } else {
      progress = 1.0 - (cycle - duration) / duration;
    }

    return Transform.scale(
      scale: 0.5 + (0.5 * progress),
      child: child,
    );
  },
)
```

### Staggered Elements

```dart
Widget buildStaggeredItems(List<Widget> items) {
  return TimeConsumer(
    builder: (context, frame, _) {
      return Stack(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final child = entry.value;

          // Each item starts 5 frames after the previous
          final itemStart = index * 5;
          final itemDuration = 20;

          double opacity;
          if (frame < itemStart) {
            opacity = 0.0;
          } else if (frame >= itemStart + itemDuration) {
            opacity = 1.0;
          } else {
            opacity = (frame - itemStart) / itemDuration;
          }

          return Opacity(
            opacity: Curves.easeOut.transform(opacity),
            child: child,
          );
        }).toList(),
      );
    },
  );
}
```

### Physics-Based Motion

```dart
class BouncingBall extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TimeConsumer(
      builder: (context, frame, _) {
        // Simple gravity simulation
        final t = frame / 30.0; // Time in seconds
        final gravity = 500.0;
        final initialVelocity = -300.0;

        // y = v0*t + 0.5*g*t^2 (with bounce)
        var y = initialVelocity * t + 0.5 * gravity * t * t;

        // Bounce when hitting the ground
        final groundY = 400.0;
        if (y > groundY) {
          y = groundY - (y - groundY) * 0.7; // Damped bounce
        }

        return Positioned(
          left: 100,
          top: y,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
```

### Conditional Visibility

```dart
TimeConsumer(
  builder: (context, frame, _) {
    // Only visible between frames 30 and 90
    if (frame < 30 || frame >= 90) {
      return const SizedBox.shrink();
    }

    return child;
  },
)
```

## Performance Tips

1. **Avoid heavy computations in builder**: The builder is called every frame. Cache expensive calculations.

2. **Use const widgets**: Mark child widgets as `const` when possible.

3. **Minimize rebuilds**: Only return new widget instances when values actually change.

```dart
// Good: Reuse widget when opacity hasn't changed
TimeConsumer(
  builder: (context, frame, _) {
    final opacity = _calculateOpacity(frame);

    // Only create new Opacity if value changed
    if (opacity == _lastOpacity) {
      return _cachedWidget!;
    }

    _lastOpacity = opacity;
    _cachedWidget = Opacity(
      opacity: opacity,
      child: const ExpensiveWidget(),
    );
    return _cachedWidget!;
  },
)
```

## FrameProvider

TimeConsumer reads frame data from a `FrameProvider` ancestor. This is automatically set up by `VideoComposition` and `RenderableComposition`. For testing or custom setups:

```dart
FrameProvider(
  frame: 45,  // Set the current frame
  child: TimeConsumer(
    builder: (context, frame, _) {
      // frame will be 45
      return Text('Frame: $frame');
    },
  ),
)
```

## Related Widgets

- **AnimatedProp**: Declarative animations with PropAnimation
- **FrameAnimatedPositioned**: Positioned widget with entry/exit animations
- **Stagger**: Automatic staggering of child animations
- **AnimationContext**: Access parent timing information
- **SyncAnchor**: Mark sync points for cross-element coordination
