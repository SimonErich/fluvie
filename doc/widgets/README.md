# Widget Reference

> **Complete guide to all Fluvie widgets**

This section documents every widget available in Fluvie, organized by category. Each widget page includes properties, examples, and usage guidelines.

## Table of Contents

- [Core Widgets](#core-widgets)
- [Layout Widgets](#layout-widgets)
- [Audio Widgets](#audio-widgets)
- [Text Widgets](#text-widgets)
- [Media Widgets](#media-widgets)
- [How to Use This Reference](#how-to-use-this-reference)

---

## Widget Categories

### Core Widgets

The fundamental building blocks for video composition:

| Widget | Description |
|--------|-------------|
| [Video](core/video.md) | High-level scene-based composition (declarative API) |
| [VideoComposition](core/video-composition.md) | Low-level composition root (full API) |
| [Scene](core/scene.md) | Time-bounded section of video |
| [Sequence](core/sequence.md) | Basic timing container |
| [TimeConsumer](core/time-consumer.md) | Frame-based animation driver |

### Layout Widgets

Video-aware layout widgets with timing and fade support:

| Widget | Description |
|--------|-------------|
| [LayerStack](layout/layer-stack.md) | Z-indexed layer composition |
| [Layer](layout/layer.md) | Individual layer with visibility timing |
| [VStack](layout/v-stack.md) | Video-aware Stack |
| [VColumn](layout/v-column.md) | Column with stagger support |
| [VRow](layout/v-row.md) | Row with stagger support |
| [VCenter](layout/v-center.md) | Centered content with timing |
| [VPadding](layout/v-padding.md) | Padded content with timing |
| [VSizedBox](layout/v-sized-box.md) | Sized box with timing |
| [VPositioned](layout/v-positioned.md) | Positioned element with hero transitions |

### Audio Widgets

Add music, sound effects, and audio-reactive features:

| Widget | Description |
|--------|-------------|
| [AudioTrack](audio/audio-track.md) | Precise audio timing and synchronization |
| [AudioSource](audio/audio-source.md) | Audio file reference types |
| [BackgroundAudio](audio/background-audio.md) | Full-video background music |
| [AudioReactive](audio/audio-reactive.md) | BPM detection and frequency analysis |

### Text Widgets

Animated typography optimized for video:

| Widget | Description |
|--------|-------------|
| [FadeText](text/fade-text.md) | Text with video-safe opacity |
| [AnimatedText](text/animated-text.md) | Pre-built text animations |
| [TypewriterText](text/typewriter-text.md) | Character-by-character reveal |
| [CounterText](text/counter-text.md) | Animated number counting |

### Media Widgets

Embed images and videos:

| Widget | Description |
|--------|-------------|
| [EmbeddedVideo](media/embedded-video.md) | Video-in-video with frame sync |
| [VideoSequence](media/video-sequence.md) | External video file reference |
| [Collage](media/collage.md) | Multi-element photo layouts |

---

## How to Use This Reference

### Page Structure

Each widget page follows this structure:

1. **Overview** - What the widget does and when to use it
2. **Properties** - Complete property reference table
3. **Examples** - Working code examples
4. **Related** - Links to related widgets

### Property Tables

Properties are documented with:

| Column | Description |
|--------|-------------|
| Property | The property name |
| Type | Dart type |
| Default | Default value (if optional) |
| Description | What the property does |

### Example Code

All examples are complete and runnable:

```dart
// Examples show full context
Video(
  fps: 30,
  width: 1920,
  height: 1080,
  scenes: [
    Scene(
      durationInFrames: 90,
      children: [
        // The widget being demonstrated
        VCenter(
          child: Text('Hello'),
        ),
      ],
    ),
  ],
)
```

---

## Quick Reference

### Choosing the Right Widget

| I want to... | Use this widget |
|--------------|-----------------|
| Create a multi-scene video | [Video](core/video.md) |
| Define scene timing | [Scene](core/scene.md) |
| Animate based on frame | [TimeConsumer](core/time-consumer.md) |
| Stack layers with z-index | [LayerStack](layout/layer-stack.md) |
| Show/hide content over time | [Layer](layout/layer.md) or [VPositioned](layout/v-positioned.md) |
| Animate children sequentially | [VColumn](layout/v-column.md) with stagger |
| Add background music | [BackgroundAudio](audio/background-audio.md) |
| Add sound effects | [AudioTrack](audio/audio-track.md) |
| Animate text entrance | [AnimatedText](text/animated-text.md) |
| Type out text | [TypewriterText](text/typewriter-text.md) |
| Count up numbers | [CounterText](text/counter-text.md) |
| Embed a video clip | [EmbeddedVideo](media/embedded-video.md) |

### Common Patterns

**Fade in content at a specific frame:**
```dart
VPositioned(
  startFrame: 30,
  fadeInFrames: 15,
  child: MyContent(),
)
```

**Staggered list animation:**
```dart
VColumn(
  stagger: StaggerConfig.slideUp(delay: 10),
  children: [Item1(), Item2(), Item3()],
)
```

**Frame-based animation:**
```dart
TimeConsumer(
  builder: (context, frame, progress) {
    return Opacity(
      opacity: progress,
      child: MyContent(),
    );
  },
)
```

---

## Related Documentation

- [Animations](../animations/README.md) - Animation system
- [Effects](../effects/README.md) - Visual effects
- [Helpers](../helpers/README.md) - Pre-built components
- [Examples](../../example/) - Working code
