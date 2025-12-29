# Layout Widgets

Layout widgets in Fluvie extend Flutter's standard layout widgets with video-specific capabilities like time-based visibility, fade transitions, and staggered animations.

## Overview

All V-prefixed layout widgets share these video timing properties:

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `startFrame` | `int?` | `null` | Frame to become visible |
| `endFrame` | `int?` | `null` | Frame to become invisible |
| `fadeInFrames` | `int` | `0` | Fade-in duration in frames |
| `fadeOutFrames` | `int` | `0` | Fade-out duration in frames |
| `fadeInCurve` | `Curve` | `easeOut` | Fade-in easing |
| `fadeOutCurve` | `Curve` | `easeIn` | Fade-out easing |

---

## Widget Reference

### Composition Widgets

| Widget | Description | Use Case |
|--------|-------------|----------|
| [LayerStack](layer-stack.md) | Video composition stack | Layering content with z-index control |
| [Layer](layer.md) | Single layer with timing | Time-controlled content with blend modes |

### Standard Layout Widgets

| Widget | Description | Flutter Equivalent |
|--------|-------------|-------------------|
| [VStack](v-stack.md) | Stack with timing | `Stack` |
| [VColumn](v-column.md) | Column with stagger support | `Column` |
| [VRow](v-row.md) | Row with stagger support | `Row` |
| [VCenter](v-center.md) | Center with timing | `Center` |
| [VPadding](v-padding.md) | Padding with timing | `Padding` |
| [VSizedBox](v-sized-box.md) | SizedBox with timing | `SizedBox` |
| [VPositioned](v-positioned.md) | Positioned with hero support | `Positioned` |

---

## Quick Comparison

### When to Use Each Widget

```dart
// LayerStack: For complex compositions with z-ordering
LayerStack(
  children: [
    Layer.background(child: Background()),
    Layer(startFrame: 30, child: Content()),
    Layer.overlay(child: Effects()),
  ],
)

// VStack: For stacking with shared timing
VStack(
  startFrame: 30,
  fadeInFrames: 15,
  children: [Background(), Content()],
)

// VColumn: For vertical layout with stagger
VColumn(
  stagger: StaggerConfig.slideUp(delay: 10),
  children: [Text('A'), Text('B'), Text('C')],
)

// VRow: For horizontal layout with stagger
VRow(
  stagger: StaggerConfig.fade(delay: 8),
  children: [Icon1(), Icon2(), Icon3()],
)

// VCenter: For centered content with timing
VCenter(
  startFrame: 0,
  fadeInFrames: 20,
  child: Title(),
)

// VPositioned: For absolute positioning
VPositioned(
  left: 50,
  bottom: 100,
  startFrame: 30,
  child: Caption(),
)
```

---

## Stagger Animations

`VColumn` and `VRow` support staggered animations where children animate in sequence:

```dart
VColumn(
  stagger: StaggerConfig.slideUp(delay: 15),
  children: [
    Text('First'),   // Starts at frame 0
    Text('Second'),  // Starts at frame 15
    Text('Third'),   // Starts at frame 30
  ],
)
```

### Available Stagger Presets

| Constructor | Effect |
|------------|--------|
| `StaggerConfig.fade()` | Fade in only |
| `StaggerConfig.slideUp()` | Slide up + fade |
| `StaggerConfig.slideDown()` | Slide down + fade |
| `StaggerConfig.slideLeft()` | Slide left + fade |
| `StaggerConfig.slideRight()` | Slide right + fade |
| `StaggerConfig.scale()` | Scale in + fade |
| `StaggerConfig.slideUpScale()` | Slide + scale + fade |

See [StaggerConfig](../../animations/stagger-config.md) for details.

---

## Common Patterns

### Title with Timed Subtitle

```dart
VCenter(
  child: VColumn(
    spacing: 20,
    children: [
      VCenter(
        startFrame: 0,
        fadeInFrames: 20,
        child: Text('Title'),
      ),
      VCenter(
        startFrame: 30,
        fadeInFrames: 20,
        child: Text('Subtitle'),
      ),
    ],
  ),
)
```

### Layered Scene

```dart
LayerStack(
  children: [
    Layer.background(
      fadeInFrames: 30,
      child: GradientBackground(),
    ),
    Layer(
      startFrame: 30,
      endFrame: 150,
      fadeInFrames: 20,
      fadeOutFrames: 20,
      child: VCenter(child: MainContent()),
    ),
    Layer.overlay(
      child: ParticleEffect.sparkles(),
    ),
  ],
)
```

### Stats Row at Bottom

```dart
VPositioned(
  left: 50,
  right: 50,
  bottom: 100,
  startFrame: 45,
  fadeInFrames: 20,
  child: VRow(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    stagger: StaggerConfig.slideUp(delay: 12),
    children: [
      StatWidget(value: '100', label: 'Songs'),
      StatWidget(value: '25', label: 'Artists'),
      StatWidget(value: '10', label: 'Hours'),
    ],
  ),
)
```

---

## Related

- [Animations](../../animations/README.md) - Animation system
- [StaggerConfig](../../animations/stagger-config.md) - Stagger configuration
- [TimeConsumer](../core/time-consumer.md) - Frame-based animation
