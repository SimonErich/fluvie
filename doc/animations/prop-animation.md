# PropAnimation

> **Base class for property animations that transform widgets**

`PropAnimation` is the foundation of Fluvie's animation system. It defines transformations that animate over a progress value from 0.0 to 1.0, making animations perfectly synchronized with frame capture.

## Table of Contents

- [Overview](#overview)
- [Factory Constructors](#factory-constructors)
- [Convenience Methods](#convenience-methods)
- [Animation Classes](#animation-classes)
- [Combining Animations](#combining-animations)
- [Examples](#examples)
- [Related](#related)

---

## Overview

`PropAnimation` applies transformations to widgets based on animation progress:

```dart
// Create an animation
final animation = PropAnimation.slideUp(distance: 50);

// Apply at different progress values
animation.apply(child, 0.0);  // Widget 50px below final position
animation.apply(child, 0.5);  // Widget 25px below final position
animation.apply(child, 1.0);  // Widget at final position
```

### Basic Usage

```dart
AnimatedProp(
  animation: PropAnimation.fadeIn(),
  duration: 30,
  child: Text('Fading in'),
)
```

---

## Factory Constructors

These create specific animation types:

### PropAnimation.translate

Animates position from one offset to another:

```dart
PropAnimation.translate(
  start: Offset(100, 0),  // Start 100px to the right
  end: Offset.zero,       // End at original position
)
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `start` | `Offset` | `Offset.zero` | Starting position |
| `end` | `Offset` | `Offset.zero` | Ending position |

### PropAnimation.scale

Animates scale from one value to another:

```dart
PropAnimation.scale(
  start: 0.0,                     // Start invisible
  end: 1.0,                       // End at full size
  alignment: Alignment.center,    // Scale from center
)
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `start` | `double` | `0.0` | Starting scale |
| `end` | `double` | `1.0` | Ending scale |
| `alignment` | `Alignment` | `center` | Scale origin |

### PropAnimation.rotate

Animates rotation from one angle to another (in radians):

```dart
PropAnimation.rotate(
  start: 0.0,                     // Start upright
  end: 3.14159,                   // End rotated 180 degrees
  alignment: Alignment.center,    // Rotate around center
)
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `start` | `double` | `0.0` | Starting angle (radians) |
| `end` | `double` | `0.0` | Ending angle (radians) |
| `alignment` | `Alignment` | `center` | Rotation origin |

### PropAnimation.fade

Animates opacity from one value to another:

```dart
PropAnimation.fade(
  start: 0.0,  // Start invisible
  end: 1.0,    // End fully visible
)
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `start` | `double` | `0.0` | Starting opacity (0-1) |
| `end` | `double` | `1.0` | Ending opacity (0-1) |

### PropAnimation.combine

Combines multiple animations:

```dart
PropAnimation.combine([
  PropAnimation.translate(start: Offset(0, 50), end: Offset.zero),
  PropAnimation.fade(start: 0.0, end: 1.0),
  PropAnimation.scale(start: 0.8, end: 1.0),
])
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `animations` | `List<PropAnimation>` | Animations to combine |

---

## Convenience Methods

Pre-configured animations for common effects:

### Slide Animations

```dart
// Slide from below to original position
PropAnimation.slideUp(distance: 30)  // Default: 30px

// Slide from above to original position
PropAnimation.slideDown(distance: 30)

// Slide from right to original position
PropAnimation.slideLeft(distance: 30)

// Slide from left to original position
PropAnimation.slideRight(distance: 30)
```

### Scale Animations

```dart
// Scale from small to full size
PropAnimation.zoomIn(start: 0.5)  // Default: 0.5

// Scale from full size to small
PropAnimation.zoomOut(end: 0.5)
```

### Fade Animations

```dart
// Fade from invisible to visible
PropAnimation.fadeIn()

// Fade from visible to invisible
PropAnimation.fadeOut()
```

### Combined Animations

```dart
// Slide up + fade in
PropAnimation.slideUpFade(distance: 30)

// Slide up + scale in
PropAnimation.slideUpScale(
  distance: 30,
  startScale: 0.8,
)
```

### Continuous Animations

For looping/oscillating effects:

```dart
// Floating motion (use with Loop widget)
PropAnimation.float(
  amplitude: Offset(0, 10),  // Move 10px up/down
  phase: 0.0,                // Starting phase
)

// Pulsing scale (use with Loop widget)
PropAnimation.pulse(
  min: 0.95,   // Minimum scale
  max: 1.05,   // Maximum scale
  phase: 0.0,
)
```

---

## Animation Classes

### TranslateAnimation

Moves widget by interpolated offset:

```dart
const TranslateAnimation(
  start: Offset(0, 100),
  end: Offset.zero,
)
```

### ScaleAnimation

Scales widget by interpolated factor:

```dart
const ScaleAnimation(
  start: 0.0,
  end: 1.0,
  alignment: Alignment.center,
)
```

### RotateAnimation

Rotates widget by interpolated angle:

```dart
const RotateAnimation(
  start: 0.0,
  end: 3.14159,  // 180 degrees
  alignment: Alignment.center,
)
```

### FadeAnimation

Changes widget opacity:

```dart
const FadeAnimation(
  start: 0.0,
  end: 1.0,
)
```

### CombinedAnimation

Applies multiple animations in sequence:

```dart
const CombinedAnimation([
  TranslateAnimation(start: Offset(0, 30), end: Offset.zero),
  FadeAnimation(start: 0.0, end: 1.0),
])
```

### FloatAnimation

Creates oscillating movement using sine wave:

```dart
const FloatAnimation(
  amplitude: Offset(0, 10),  // X and Y movement range
  phase: 0.0,                // Phase offset (0-1)
)
```

### PulseAnimation

Creates oscillating scale using sine wave:

```dart
const PulseAnimation(
  min: 0.95,   // Minimum scale
  max: 1.05,   // Maximum scale
  phase: 0.0,  // Phase offset (0-1)
)
```

---

## Combining Animations

### Multiple Effects

Combine any animations for complex effects:

```dart
final animation = PropAnimation.combine([
  PropAnimation.slideUp(distance: 50),
  PropAnimation.fadeIn(),
  PropAnimation.zoomIn(start: 0.9),
]);

AnimatedProp(
  animation: animation,
  duration: 40,
  curve: Easing.easeOutCubic,
  child: MyWidget(),
)
```

### Order Matters

Animations are applied in order. This affects rotation/scale origin:

```dart
// Translate then rotate: rotates around original center
PropAnimation.combine([
  PropAnimation.translate(...),
  PropAnimation.rotate(...),
])

// Rotate then translate: rotates around new position
PropAnimation.combine([
  PropAnimation.rotate(...),
  PropAnimation.translate(...),
])
```

---

## Examples

### Basic Slide-Up

```dart
AnimatedProp(
  animation: PropAnimation.slideUp(),
  duration: 30,
  startFrame: 0,
  child: Text(
    'Hello World',
    style: TextStyle(fontSize: 48, color: Colors.white),
  ),
)
```

### Dramatic Entrance

```dart
AnimatedProp(
  animation: PropAnimation.combine([
    PropAnimation.slideUp(distance: 100),
    PropAnimation.fadeIn(),
    PropAnimation.zoomIn(start: 0.5),
  ]),
  duration: 45,
  curve: Easing.easeOutBack,
  child: Container(
    padding: EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.blue,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text('Featured'),
  ),
)
```

### Rotating Icon

```dart
TimeConsumer(
  builder: (context, frame, child) {
    // One full rotation over 60 frames
    final progress = (frame % 60) / 60;
    final rotation = PropAnimation.rotate(
      start: 0,
      end: 2 * 3.14159,
    );
    return rotation.apply(child!, progress);
  },
  child: Icon(Icons.refresh, size: 48),
)
```

### Floating Element

```dart
// Requires a Loop widget or continuous frame updates
TimeConsumer(
  builder: (context, frame, child) {
    final progress = (frame % 120) / 120;  // 4 second cycle at 30fps
    final float = PropAnimation.float(
      amplitude: Offset(0, 15),
    );
    return float.apply(child!, progress);
  },
  child: Image.asset('assets/cloud.png'),
)
```

### Exit Animation

```dart
// Fade out while scaling down
AnimatedProp(
  animation: PropAnimation.combine([
    PropAnimation.fadeOut(),
    PropAnimation.zoomOut(end: 0.8),
  ]),
  duration: 25,
  startFrame: 150,  // Start exit at frame 150
  curve: Easing.easeInCubic,
  child: MyContent(),
)
```

### Spin In

```dart
AnimatedProp(
  animation: PropAnimation.combine([
    PropAnimation.rotate(start: -3.14159, end: 0),  // 180 degree spin
    PropAnimation.fadeIn(),
    PropAnimation.zoomIn(start: 0.3),
  ]),
  duration: 40,
  curve: Easing.easeOutBack,
  child: Icon(Icons.star, size: 64, color: Colors.yellow),
)
```

---

## Creating Custom Animations

Extend `PropAnimation` for custom effects:

```dart
class BlurAnimation extends PropAnimation {
  final double startBlur;
  final double endBlur;

  const BlurAnimation({
    this.startBlur = 10.0,
    this.endBlur = 0.0,
  });

  @override
  Widget apply(Widget child, double progress) {
    final blur = startBlur + (endBlur - startBlur) * progress;
    if (blur == 0.0) return child;

    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: child,
    );
  }
}
```

---

## Related

- [EntryAnimation](entry-animations.md) - Specialized reveal animations
- [StaggerConfig](stagger-config.md) - Sequential animations
- [Easing](easing.md) - Animation curves
- [interpolate()](interpolate.md) - Keyframe animation
- [AnimatedProp](../widgets/core/animated-prop.md) - Animation widget
