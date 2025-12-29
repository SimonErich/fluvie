# Custom Animations

> **Create reusable animation patterns**

Build custom animations that integrate with Fluvie's frame-based animation system.

## Table of Contents

- [Overview](#overview)
- [PropAnimation](#propanimation)
- [Entry Animations](#entry-animations)
- [Interpolation Functions](#interpolation-functions)
- [Testing Animations](#testing-animations)
- [Examples](#examples)

---

## Overview

Fluvie's animation system is frame-based and deterministic. Custom animations should:

1. Accept frame numbers as input
2. Return consistent values for the same frame
3. Support easing curves
4. Work in both preview and render modes

---

## PropAnimation

### Creating a Custom PropAnimation

```dart
class BounceAnimation extends PropAnimation {
  final double bounceHeight;
  final int bounces;

  const BounceAnimation({
    this.bounceHeight = 50.0,
    this.bounces = 3,
    super.curve = Curves.linear,
  });

  @override
  Matrix4 transformAt(double progress) {
    // Calculate bounce position
    final bounceProgress = progress * bounces;
    final currentBounce = bounceProgress.floor();
    final bouncePhase = bounceProgress - currentBounce;

    // Damping: each bounce is smaller
    final damping = 1.0 / (currentBounce + 1);

    // Parabolic motion within each bounce
    final y = -4 * bouncePhase * (bouncePhase - 1) * bounceHeight * damping;

    return Matrix4.identity()..translate(0.0, y);
  }

  @override
  double opacityAt(double progress) => 1.0;  // No opacity change
}
```

### Using Your Animation

```dart
AnimatedProp(
  startFrame: 0,
  duration: 60,
  animation: BounceAnimation(
    bounceHeight: 100,
    bounces: 4,
  ),
  child: Image.asset('assets/ball.png'),
)
```

### Combining with Built-in Animations

```dart
AnimatedProp(
  startFrame: 0,
  duration: 60,
  animation: PropAnimation.combine([
    BounceAnimation(bounceHeight: 50),
    PropAnimation.fadeIn(),
  ]),
  child: content,
)
```

---

## PropAnimation Methods

When creating custom `PropAnimation` subclasses, override these methods:

### transformAt(double progress)

Returns the transformation matrix at the given progress (0.0 to 1.0):

```dart
@override
Matrix4 transformAt(double progress) {
  // progress: 0.0 = start, 1.0 = end

  final scale = 1.0 + progress * 0.5;  // Scale from 1x to 1.5x
  final rotation = progress * pi;       // Rotate 180 degrees

  return Matrix4.identity()
    ..scale(scale)
    ..rotateZ(rotation);
}
```

### opacityAt(double progress)

Returns the opacity at the given progress:

```dart
@override
double opacityAt(double progress) {
  // Fade in during first half
  if (progress < 0.5) {
    return progress * 2;
  }
  return 1.0;
}
```

### colorAt(double progress)

Returns a color tint at the given progress (optional):

```dart
@override
Color? colorAt(double progress) {
  return Color.lerp(Colors.red, Colors.blue, progress);
}
```

---

## Entry Animations

### Creating a Custom EntryAnimation

```dart
class TypewriterEntry extends EntryAnimation {
  final Duration charDelay;

  const TypewriterEntry({
    this.charDelay = const Duration(milliseconds: 50),
    super.duration = const Duration(milliseconds: 500),
    super.curve = Curves.easeOut,
  });

  @override
  Widget buildAnimation(
    BuildContext context,
    Animation<double> animation,
    Widget child,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        if (child is Text) {
          final text = child.data ?? '';
          final visibleChars = (text.length * animation.value).round();

          return Text(
            text.substring(0, visibleChars),
            style: child.style,
          );
        }
        return child!;
      },
      child: child,
    );
  }
}
```

### Entry Animation Factory

```dart
class CustomEntryAnimations {
  static EntryAnimation typewriter({
    Duration charDelay = const Duration(milliseconds: 50),
  }) {
    return TypewriterEntry(charDelay: charDelay);
  }

  static EntryAnimation glitch({
    int glitchCount = 5,
  }) {
    return GlitchEntry(glitchCount: glitchCount);
  }
}
```

---

## Interpolation Functions

### Custom Interpolation

Create specialized interpolation for complex animations:

```dart
/// Interpolates along a bezier curve path
double bezierInterpolate({
  required int frame,
  required int startFrame,
  required int endFrame,
  required List<Offset> controlPoints,
  Curve curve = Curves.linear,
}) {
  final progress = ((frame - startFrame) / (endFrame - startFrame))
      .clamp(0.0, 1.0);
  final easedProgress = curve.transform(progress);

  return _evaluateBezier(controlPoints, easedProgress);
}

double _evaluateBezier(List<Offset> points, double t) {
  // De Casteljau's algorithm
  if (points.length == 1) return points[0].dy;

  final newPoints = <Offset>[];
  for (var i = 0; i < points.length - 1; i++) {
    newPoints.add(Offset.lerp(points[i], points[i + 1], t)!);
  }

  return _evaluateBezier(newPoints, t);
}
```

### Spring Physics

```dart
class SpringAnimation {
  final double stiffness;
  final double damping;
  final double mass;

  const SpringAnimation({
    this.stiffness = 100.0,
    this.damping = 10.0,
    this.mass = 1.0,
  });

  double valueAt(double progress) {
    // Damped harmonic oscillator
    final omega = sqrt(stiffness / mass);
    final zeta = damping / (2 * sqrt(stiffness * mass));

    if (zeta < 1) {
      // Underdamped
      final omegaD = omega * sqrt(1 - zeta * zeta);
      return 1 - exp(-zeta * omega * progress) *
             cos(omegaD * progress);
    } else {
      // Critically or overdamped
      return 1 - exp(-omega * progress);
    }
  }
}
```

---

## Testing Animations

### Frame-by-Frame Testing

```dart
void main() {
  group('BounceAnimation', () {
    test('starts at rest position', () {
      final animation = BounceAnimation(bounceHeight: 50);
      final transform = animation.transformAt(0.0);

      // Should be at y=0 at start
      expect(transform.getTranslation().y, equals(0.0));
    });

    test('reaches peak at mid-bounce', () {
      final animation = BounceAnimation(bounceHeight: 50, bounces: 1);
      final transform = animation.transformAt(0.5);

      // Should be at peak height mid-bounce
      expect(transform.getTranslation().y, closeTo(-50.0, 0.1));
    });

    test('returns to rest at end', () {
      final animation = BounceAnimation(bounceHeight: 50);
      final transform = animation.transformAt(1.0);

      expect(transform.getTranslation().y, closeTo(0.0, 0.1));
    });
  });
}
```

### Visual Testing

```dart
testWidgets('BounceAnimation visual test', (tester) async {
  final animation = BounceAnimation(bounceHeight: 100);

  // Test at key frames
  for (final frame in [0, 15, 30, 45, 60]) {
    final progress = frame / 60;

    await tester.pumpWidget(
      MaterialApp(
        home: Transform(
          transform: animation.transformAt(progress),
          child: Container(
            width: 50,
            height: 50,
            color: Colors.blue,
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(Container),
      matchesGoldenFile('bounce_frame_$frame.png'),
    );
  }
});
```

---

## Examples

### Shake Animation

```dart
class ShakeAnimation extends PropAnimation {
  final double intensity;
  final int shakes;

  const ShakeAnimation({
    this.intensity = 10.0,
    this.shakes = 5,
    super.curve = Curves.easeOut,
  });

  @override
  Matrix4 transformAt(double progress) {
    // Damped shake
    final damping = 1.0 - progress;
    final shakeProgress = progress * shakes * 2 * pi;
    final offset = sin(shakeProgress) * intensity * damping;

    return Matrix4.identity()..translate(offset, 0.0);
  }

  @override
  double opacityAt(double progress) => 1.0;
}
```

### Wobble Animation

```dart
class WobbleAnimation extends PropAnimation {
  final double angle;
  final int wobbles;

  const WobbleAnimation({
    this.angle = 0.1,  // radians
    this.wobbles = 3,
    super.curve = Curves.easeInOut,
  });

  @override
  Matrix4 transformAt(double progress) {
    final damping = 1.0 - progress;
    final wobbleAngle = sin(progress * wobbles * 2 * pi) * angle * damping;

    return Matrix4.identity()..rotateZ(wobbleAngle);
  }

  @override
  double opacityAt(double progress) => 1.0;
}
```

### Path-Following Animation

```dart
class PathAnimation extends PropAnimation {
  final Path path;
  final PathMetric _pathMetric;

  PathAnimation({required this.path})
      : _pathMetric = path.computeMetrics().first;

  @override
  Matrix4 transformAt(double progress) {
    final distance = _pathMetric.length * progress;
    final tangent = _pathMetric.getTangentForOffset(distance);

    if (tangent == null) return Matrix4.identity();

    return Matrix4.identity()
      ..translate(tangent.position.dx, tangent.position.dy)
      ..rotateZ(tangent.angle);
  }

  @override
  double opacityAt(double progress) => 1.0;
}

// Usage
final heartPath = Path()
  ..moveTo(100, 50)
  ..cubicTo(100, 0, 50, 0, 50, 50)
  ..cubicTo(50, 80, 100, 100, 100, 130)
  ..cubicTo(100, 100, 150, 80, 150, 50)
  ..cubicTo(150, 0, 100, 0, 100, 50);

AnimatedProp(
  startFrame: 0,
  duration: 90,
  animation: PathAnimation(path: heartPath),
  child: Icon(Icons.favorite, color: Colors.red),
)
```

---

## Related

- [PropAnimation](../animations/prop-animation.md) - Built-in animations
- [Entry Animations](../animations/entry-animations.md) - Entry animation system
- [Interpolate](../animations/interpolate.md) - Interpolation function
- [TimeConsumer](../widgets/core/time-consumer.md) - Frame-based widget

