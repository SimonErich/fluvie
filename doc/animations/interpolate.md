# interpolate()

> **Keyframe-based value interpolation for frame animations**

The `interpolate()` function performs piecewise linear interpolation between keyframes, enabling complex multi-segment animations with optional easing curves.

## Table of Contents

- [Overview](#overview)
- [Parameters](#parameters)
- [Examples](#examples)
- [lerpValue Helper](#lerpvalue-helper)
- [Advanced Usage](#advanced-usage)
- [Related](#related)

---

## Overview

`interpolate()` maps frame numbers to output values through keyframes:

```dart
// Frames 0-30: value goes from 0 to 100
final value = interpolate(15, [0, 30], [0.0, 100.0]);
// value == 50.0 (halfway)
```

### Why Use interpolate()?

- **Multi-segment animations** - Create complex timing with multiple keyframes
- **Frame-precise** - Works with frame numbers for deterministic rendering
- **Easing support** - Apply curves to each segment
- **Extrapolation** - Optionally extend beyond the defined range

---

## Parameters

```dart
double interpolate(
  int frame,
  List<int> inputRange,
  List<double> outputRange, {
  bool extrapolate = false,
  Curve curve = Curves.linear,
})
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `frame` | `int` | **required** | Current frame number |
| `inputRange` | `List<int>` | **required** | Frame keypoints (sorted ascending, min 2) |
| `outputRange` | `List<double>` | **required** | Corresponding values (same length) |
| `extrapolate` | `bool` | `false` | Extend beyond range |
| `curve` | `Curve` | `Curves.linear` | Easing curve for segments |

### Validation

The function throws `ArgumentError` if:
- `inputRange` and `outputRange` have different lengths
- `inputRange` has fewer than 2 elements
- `inputRange` is not sorted in ascending order

---

## Examples

### Simple Linear

```dart
// Opacity from 0 to 1 over 30 frames
TimeConsumer(
  builder: (context, frame, child) {
    final opacity = interpolate(
      frame,
      [0, 30],
      [0.0, 1.0],
    );
    return Opacity(opacity: opacity, child: child);
  },
  child: Text('Fading in'),
)
```

### With Easing

```dart
// Smooth ease-out opacity
final opacity = interpolate(
  frame,
  [0, 30],
  [0.0, 1.0],
  curve: Curves.easeOut,
);
```

### Multi-Segment (Fade In, Hold, Fade Out)

```dart
TimeConsumer(
  builder: (context, frame, child) {
    final opacity = interpolate(
      frame,
      [0, 30, 90, 120],    // Keyframes
      [0.0, 1.0, 1.0, 0.0], // Values
    );
    return Opacity(opacity: opacity, child: child);
  },
  child: Text('Appears and disappears'),
)
```

**Timeline:**
```
Frame:    0        30        90       120
          |         |         |         |
Opacity:  0 ───────> 1 ═══════> 1 ───────> 0
          [fade in]  [hold]    [fade out]
```

### Bounce Back

```dart
// Position moves right, then back
final xPosition = interpolate(
  frame,
  [0, 30, 60],
  [0.0, 200.0, 100.0],
);
```

**Timeline:**
```
Frame:    0        30        60
          |         |         |
X:        0 ───────> 200 ────> 100
          [move right] [return]
```

### Scale Animation

```dart
TimeConsumer(
  builder: (context, frame, child) {
    final scale = interpolate(
      frame,
      [0, 20, 25, 30],
      [0.0, 1.2, 0.9, 1.0],  // Pop effect
      curve: Curves.easeOut,
    );
    return Transform.scale(scale: scale, child: child);
  },
  child: Icon(Icons.star, size: 64),
)
```

### Complex Path

```dart
// Animate along a custom path
final x = interpolate(frame, [0, 30, 60, 90], [0.0, 100.0, 50.0, 150.0]);
final y = interpolate(frame, [0, 30, 60, 90], [0.0, -50.0, 20.0, 0.0]);

Transform.translate(
  offset: Offset(x, y),
  child: myWidget,
)
```

### Rotation

```dart
// Spin 360 degrees
final rotation = interpolate(
  frame,
  [0, 60],
  [0.0, 2 * 3.14159],  // 0 to 2π radians
  curve: Curves.easeInOut,
);

Transform.rotate(angle: rotation, child: icon)
```

### Color Component Animation

```dart
// Animate color channels separately
final red = interpolate(frame, [0, 30], [255.0, 0.0]);
final green = interpolate(frame, [0, 30], [0.0, 255.0]);
final blue = interpolate(frame, [0, 30], [0.0, 0.0]);

Container(
  color: Color.fromRGBO(red.toInt(), green.toInt(), blue.toInt(), 1.0),
)
```

### Extrapolation

```dart
// Without extrapolation (default)
interpolate(-10, [0, 30], [0.0, 100.0]);  // Returns 0.0 (clamped)
interpolate(50, [0, 30], [0.0, 100.0]);   // Returns 100.0 (clamped)

// With extrapolation
interpolate(-10, [0, 30], [0.0, 100.0], extrapolate: true);  // Returns -33.33
interpolate(50, [0, 30], [0.0, 100.0], extrapolate: true);   // Returns 166.67
```

---

## lerpValue Helper

For simple two-value interpolation with a progress (0-1):

```dart
double lerpValue(
  double t,
  double begin,
  double end, {
  Curve curve = Curves.linear,
})
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `t` | `double` | **required** | Progress (0.0 to 1.0) |
| `begin` | `double` | **required** | Starting value |
| `end` | `double` | **required** | Ending value |
| `curve` | `Curve` | `Curves.linear` | Easing curve |

### lerpValue Examples

```dart
// Linear interpolation
lerpValue(0.5, 0.0, 100.0);  // 50.0

// With easing
lerpValue(0.5, 0.0, 100.0, curve: Curves.easeOut);  // ~70.7

// Use when you already have progress calculated
final progress = (frame - startFrame) / duration;
final opacity = lerpValue(progress, 0.0, 1.0, curve: Curves.easeIn);
```

---

## Advanced Usage

### Stair-Step Values

Create discrete steps:

```dart
// Jump between values
final step = interpolate(
  frame,
  [0, 1, 30, 31, 60, 61, 90],
  [0.0, 1.0, 1.0, 2.0, 2.0, 3.0, 3.0],
);
// Result: 0 at frame 0, 1 from frames 1-30, 2 from 31-60, 3 from 61+
```

### Hold Values

Keep value constant for a range:

```dart
// Fade in, hold, fade out
final opacity = interpolate(
  frame,
  [0, 30, 120, 150],  // Long hold period (frames 30-120)
  [0.0, 1.0, 1.0, 0.0],
);
```

### Synchronized Multiple Properties

```dart
TimeConsumer(
  builder: (context, frame, child) {
    // All properties on the same timeline
    final opacity = interpolate(frame, [0, 30, 90, 120], [0.0, 1.0, 1.0, 0.0]);
    final scale = interpolate(frame, [0, 30, 90, 120], [0.5, 1.0, 1.0, 0.8]);
    final yOffset = interpolate(frame, [0, 30, 90, 120], [50.0, 0.0, 0.0, -30.0]);

    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Transform.translate(
          offset: Offset(0, yOffset),
          child: child,
        ),
      ),
    );
  },
  child: myContent,
)
```

### Different Curves Per Segment

Apply different curves to different segments by calculating manually:

```dart
TimeConsumer(
  builder: (context, frame, child) {
    double opacity;

    if (frame < 30) {
      // Fade in with ease-out
      final progress = frame / 30;
      opacity = lerpValue(progress, 0.0, 1.0, curve: Curves.easeOut);
    } else if (frame < 90) {
      // Hold at 1
      opacity = 1.0;
    } else {
      // Fade out with ease-in
      final progress = (frame - 90) / 30;
      opacity = lerpValue(progress, 1.0, 0.0, curve: Curves.easeIn);
    }

    return Opacity(opacity: opacity.clamp(0.0, 1.0), child: child);
  },
  child: myContent,
)
```

### Counter Animation

```dart
TimeConsumer(
  builder: (context, frame, child) {
    final value = interpolate(
      frame,
      [0, 60],
      [0.0, 1000.0],
      curve: Curves.easeOutCubic,
    );

    return Text(
      '${value.toInt()}',
      style: TextStyle(fontSize: 64, fontWeight: FontWeight.bold),
    );
  },
)
```

### Progress Bar

```dart
TimeConsumer(
  builder: (context, frame, child) {
    final progress = interpolate(
      frame,
      [0, 90],
      [0.0, 1.0],
      curve: Curves.easeInOut,
    );

    return Container(
      width: 400,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(10),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  },
)
```

---

## Comparison with PropAnimation

| Use Case | interpolate() | PropAnimation |
|----------|---------------|---------------|
| Simple transforms | More verbose | Cleaner API |
| Multi-segment timing | Natural fit | Requires manual work |
| Custom value types | Direct access | Widget transforms only |
| Complex keyframes | Ideal | Not supported |

```dart
// PropAnimation: Simple slide-up
PropAnimation.slideUp(distance: 50)

// interpolate(): Same effect, more control
final yOffset = interpolate(frame, [0, 30], [50.0, 0.0], curve: Curves.easeOut);
Transform.translate(offset: Offset(0, yOffset), child: widget)
```

---

## Related

- [TimeConsumer](../widgets/core/time-consumer.md) - Access current frame
- [PropAnimation](prop-animation.md) - Widget animations
- [Easing](easing.md) - Available curves
