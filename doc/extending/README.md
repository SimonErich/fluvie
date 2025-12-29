# Extending Fluvie

> **Build custom animations, effects, templates, and integrations**

Fluvie is designed to be extensible. This section covers how to create custom components that integrate seamlessly with the framework.

## Table of Contents

- [Overview](#overview)
- [Extension Points](#extension-points)
- [Guides](#guides)

---

## Overview

Fluvie provides several extension mechanisms:

1. **Custom Animations**: Create reusable animation patterns
2. **Custom Effects**: Build visual effect widgets
3. **Custom Templates**: Package complete video templates
4. **Custom FFmpeg Providers**: Integrate different FFmpeg implementations

---

## Extension Points

### Animations

Extend the animation system by:
- Creating `PropAnimation` subclasses
- Building custom `EntryAnimation` types
- Implementing frame-based interpolation functions

**Guide**: [Custom Animations](custom-animations.md)

### Effects

Create visual effects using:
- `TimeConsumer` for frame-based effects
- Custom paint operations
- Particle systems

**Guide**: [Custom Effects](custom-effects.md)

### Templates

Build reusable video templates:
- Extend `WrappedTemplate` base class
- Define data contracts
- Support theming and timing

**Guide**: [Custom Templates](custom-templates.md)

### FFmpeg Providers

Implement FFmpeg integrations:
- Platform-specific implementations
- Mobile FFmpegKit support
- Custom encoding pipelines

**Guide**: [Custom FFmpeg Provider](custom-ffmpeg-provider.md)

---

## Guides

| Guide | Description |
|-------|-------------|
| [Custom Animations](custom-animations.md) | Create reusable animation patterns |
| [Custom Effects](custom-effects.md) | Build visual effect widgets |
| [Custom Templates](custom-templates.md) | Package complete video templates |
| [Custom FFmpeg Provider](custom-ffmpeg-provider.md) | FFmpeg integration options |

---

## Best Practices

### 1. Keep It Deterministic

All custom components must produce identical output for identical input:

```dart
// GOOD - Deterministic
TimeConsumer(
  builder: (context, frame, _) {
    final random = Random(frame);  // Seeded with frame
    return randomElement(random);
  },
)

// BAD - Non-deterministic
TimeConsumer(
  builder: (context, frame, _) {
    final random = Random();  // Different every render
    return randomElement(random);
  },
)
```

### 2. Support Both Modes

Ensure your components work in both preview and render modes:

```dart
Widget build(BuildContext context) {
  final isPreview = RenderModeProvider.of(context).isPreview;

  if (isPreview) {
    // Lighter version for preview
  } else {
    // Full quality for render
  }
}
```

### 3. Document Your Components

Include:
- Property descriptions
- Usage examples
- Performance characteristics
- Known limitations

### 4. Test Thoroughly

Write tests that verify:
- Visual output at key frames
- Animation timing
- Edge cases (frame 0, last frame)
- Performance benchmarks

---

## Related

- [Architecture](../concept/architecture.md) - Fluvie's design
- [Rendering Pipeline](../concept/rendering-pipeline.md) - How rendering works
- [Contributing](../contributing/README.md) - Contribute to Fluvie

