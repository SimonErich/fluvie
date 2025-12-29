# Animations

Fluvie provides a powerful, frame-based animation system designed for deterministic video rendering. Animations in Fluvie work with progress values (0.0 to 1.0) rather than time, making them perfectly synchronized with frame capture.

## Overview

| Topic | Description |
|-------|-------------|
| [PropAnimation](prop-animation.md) | Base animation class for transforms |
| [EntryAnimation](entry-animations.md) | Specialized reveal animations |
| [StaggerConfig](stagger-config.md) | Sequential child animations |
| [interpolate()](interpolate.md) | Keyframe-based value interpolation |
| [Easing](easing.md) | Animation curves reference |

---

## Quick Examples

### Basic Animation

```dart
AnimatedProp(
  duration: 30,
  animation: PropAnimation.slideUp(),
  child: Text('Hello World'),
)
```

### Combined Animation

```dart
AnimatedProp(
  duration: 45,
  animation: PropAnimation.combine([
    PropAnimation.slideUp(distance: 50),
    PropAnimation.fadeIn(),
    PropAnimation.zoomIn(start: 0.8),
  ]),
  curve: Easing.easeOutCubic,
  child: MyContent(),
)
```

### Staggered List

```dart
VColumn(
  stagger: StaggerConfig.slideUp(delay: 10, duration: 30),
  children: [
    Text('Item 1'),  // Starts at frame 0
    Text('Item 2'),  // Starts at frame 10
    Text('Item 3'),  // Starts at frame 20
  ],
)
```

### Keyframe Animation

```dart
TimeConsumer(
  builder: (context, frame, child) {
    final opacity = interpolate(
      frame,
      [0, 30, 60, 90],
      [0.0, 1.0, 1.0, 0.0],
      curve: Easing.easeInOut,
    );
    return Opacity(opacity: opacity, child: child);
  },
  child: Text('Fade in and out'),
)
```

---

## Animation Concepts

### Progress-Based Animation

All animations in Fluvie work with a progress value from 0.0 (start) to 1.0 (end):

```dart
// PropAnimation.apply(child, progress)
animation.apply(myWidget, 0.0);  // Initial state
animation.apply(myWidget, 0.5);  // Halfway
animation.apply(myWidget, 1.0);  // Final state
```

### Frame-Based Timing

Durations are specified in frames, not milliseconds:

```dart
// At 30fps:
// 30 frames = 1 second
// 15 frames = 0.5 seconds
// 60 frames = 2 seconds

AnimatedProp(
  duration: 45,  // 1.5 seconds at 30fps
  ...
)
```

### Easing Curves

Curves transform linear progress into shaped motion:

```dart
// Linear: constant speed
// easeOut: fast start, slow end (most common)
// easeInOut: slow start and end
// easeOutBack: overshoot at end

AnimatedProp(
  curve: Easing.easeOutCubic,
  ...
)
```

---

## Animation Types

### Transform Animations

Move, scale, rotate, or fade elements:

| Method | Effect |
|--------|--------|
| `PropAnimation.translate()` | Move by offset |
| `PropAnimation.scale()` | Scale up/down |
| `PropAnimation.rotate()` | Rotate by radians |
| `PropAnimation.fade()` | Change opacity |

### Convenience Animations

Pre-configured common animations:

| Method | Effect |
|--------|--------|
| `PropAnimation.slideUp()` | Slide from below |
| `PropAnimation.slideDown()` | Slide from above |
| `PropAnimation.slideLeft()` | Slide from right |
| `PropAnimation.slideRight()` | Slide from left |
| `PropAnimation.zoomIn()` | Scale up |
| `PropAnimation.zoomOut()` | Scale down |
| `PropAnimation.fadeIn()` | Fade from 0 to 1 |
| `PropAnimation.fadeOut()` | Fade from 1 to 0 |
| `PropAnimation.slideUpFade()` | Combined slide + fade |

### Entry Animations

Dramatic reveal effects:

| Type | Effect |
|------|--------|
| `EntryAnimation.elasticPop()` | Spring-like pop with overshoot |
| `EntryAnimation.strobeReveal()` | Flickering reveal |
| `EntryAnimation.glitchSlide()` | RGB echo glitch effect |
| `EntryAnimation.maskedWipe()` | Shape-based reveal |

### Continuous Animations

For looping motion:

| Method | Effect |
|--------|--------|
| `PropAnimation.float()` | Oscillating movement |
| `PropAnimation.pulse()` | Oscillating scale |

---

## Using with Widgets

### AnimatedProp Widget

The primary way to apply animations:

```dart
AnimatedProp(
  animation: PropAnimation.slideUpFade(),
  duration: 30,
  startFrame: 60,
  curve: Easing.easeOut,
  child: Text('Animated text'),
)
```

### VColumn/VRow with Stagger

Automatic sequential animation:

```dart
VColumn(
  stagger: StaggerConfig(
    delay: 15,
    duration: 30,
    fadeIn: true,
    slideIn: true,
    slideOffset: Offset(0, 40),
  ),
  children: myWidgets,
)
```

### TimeConsumer with interpolate()

Full manual control:

```dart
TimeConsumer(
  builder: (context, frame, child) {
    final scale = interpolate(frame, [0, 30], [0.5, 1.0]);
    final rotation = interpolate(frame, [0, 60], [0.0, 6.28]);

    return Transform.scale(
      scale: scale,
      child: Transform.rotate(
        angle: rotation,
        child: child,
      ),
    );
  },
  child: Icon(Icons.star),
)
```

---

## Best Practices

### 1. Use Convenience Methods

```dart
// Good: Clear intent
PropAnimation.slideUpFade()

// Verbose: Same effect
PropAnimation.combine([
  PropAnimation.translate(start: Offset(0, 30), end: Offset.zero),
  PropAnimation.fade(start: 0.0, end: 1.0),
])
```

### 2. Choose Appropriate Curves

```dart
// Elements entering: easeOut (fast start, gentle landing)
curve: Easing.easeOutCubic

// Elements exiting: easeIn (gentle start, fast exit)
curve: Easing.easeInCubic

// Emphasis/attention: easeOutBack (overshoot)
curve: Easing.easeOutBack
```

### 3. Keep Durations Reasonable

```dart
// Text/small elements: 15-30 frames
AnimatedProp(duration: 20, ...)

// Large elements/containers: 30-45 frames
AnimatedProp(duration: 40, ...)

// Dramatic reveals: 45-60 frames
AnimatedProp(duration: 50, ...)
```

### 4. Stagger Appropriately

```dart
// Fast stagger: items appear quickly
StaggerConfig(delay: 5, duration: 20)

// Medium stagger: comfortable reading pace
StaggerConfig(delay: 10, duration: 25)

// Slow stagger: dramatic reveals
StaggerConfig(delay: 20, duration: 40)
```

---

## Related

- [AnimatedProp](../widgets/core/animated-prop.md) - Animation widget
- [TimeConsumer](../widgets/core/time-consumer.md) - Frame access
- [VColumn](../widgets/layout/v-column.md) - Column with stagger
- [VRow](../widgets/layout/v-row.md) - Row with stagger
