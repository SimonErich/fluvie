# Advanced Features

> **Deep dives into Fluvie's advanced capabilities**

This section covers advanced topics for users who want to fine-tune rendering, synchronize audio with visuals, optimize performance, or customize the rendering pipeline.

## Table of Contents

- [Topics](#topics)
- [When You Need Advanced Features](#when-you-need-advanced-features)
- [Related](#related)

---

## Topics

| Guide | Description |
|-------|-------------|
| [Encoding Settings](encoding-settings.md) | Quality, format, and compression options |
| [Sync Anchors](sync-anchors.md) | Precise audio-visual synchronization |
| [Custom Render Pipeline](custom-render-pipeline.md) | Customizing the rendering process |
| [Frame Extraction](frame-extraction.md) | Extracting frames from video files |
| [Performance Tips](performance-tips.md) | Optimization strategies |

---

## When You Need Advanced Features

### Encoding Settings

Use when you need to:
- Adjust video quality vs file size
- Export in specific formats
- Control compression settings
- Debug rendering issues

### Sync Anchors

Use when you need to:
- Sync animations to beat drops
- Align visuals with specific audio moments
- Create music-reactive content
- Ensure frame-perfect timing

### Custom Render Pipeline

Use when you need to:
- Pre-process or post-process frames
- Integrate with external services
- Create custom progress reporting
- Handle special output formats

### Frame Extraction

Use when you need to:
- Extract thumbnails from videos
- Create video preview images
- Analyze video content
- Build video editing features

### Performance Tips

Use when you need to:
- Render faster
- Reduce memory usage
- Handle large compositions
- Optimize for production

---

## Quick Tips

### Quality vs Speed

```dart
// Fast preview quality
RenderQuality.preview  // Lower quality, faster

// Balanced
RenderQuality.standard  // Good quality, reasonable speed

// Maximum quality
RenderQuality.high  // Best quality, slower
```

### Memory Management

- Use `saveLayer` sparingly (prefer Fluvie's `Fade` widgets)
- Match image resolutions to output size
- Pre-trim videos before embedding
- Clear caches between renders

### Debugging

Enable debug frames to inspect individual frames:

```dart
EncodingConfig(
  debugOutputFrames: true,  // Saves individual frame PNGs
)
```

---

## Related

- [Concept: Rendering Pipeline](../concept/rendering-pipeline.md)
- [Concept: Two Modes](../concept/two-modes.md)
- [ONLY_SERVER_MODE](../ONLY_SERVER_MODE.md)
