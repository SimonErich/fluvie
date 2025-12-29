# Performance Tips

> **Optimizing Fluvie compositions for speed and efficiency**

This guide covers optimization strategies for faster rendering, lower memory usage, and smoother previews.

## Table of Contents

- [Overview](#overview)
- [Rendering Speed](#rendering-speed)
- [Memory Management](#memory-management)
- [Widget Optimization](#widget-optimization)
- [Media Optimization](#media-optimization)
- [Profiling](#profiling)

---

## Overview

Performance bottlenecks typically occur in:

1. **Frame Capture**: Converting widgets to images
2. **Media Processing**: Loading images, extracting video frames
3. **Encoding**: FFmpeg video encoding
4. **Memory**: Large images, many cached frames

---

## Rendering Speed

### Use Appropriate Quality

```dart
// For testing - fastest
EncodingConfig(quality: RenderQuality.preview)

// For final output
EncodingConfig(quality: RenderQuality.high)
```

### Preview vs Full Render

Test compositions at lower resolution:

```dart
// Preview at half resolution
Video(
  fps: 30,
  width: 540,   // Half of 1080
  height: 960,  // Half of 1920
  ...
)

// Final render at full resolution
Video(
  fps: 30,
  width: 1080,
  height: 1920,
  ...
)
```

### Reduce Frame Rate for Testing

```dart
// 15fps for quick tests (half the frames)
Video(fps: 15, ...)

// 30fps for final
Video(fps: 30, ...)
```

### Shorter Test Duration

```dart
// Test with just the first scene
Video(
  scenes: [scenes.first],  // Only first scene
  ...
)
```

---

## Memory Management

### Avoid saveLayer

Flutter's `saveLayer` is expensive. Avoid widgets that use it:

```dart
// BAD - Opacity uses saveLayer
Opacity(
  opacity: 0.5,
  child: complexWidget,
)

// GOOD - Use Fluvie's Fade widget
Fade(
  startFrame: 0,
  fadeInFrames: 30,
  child: complexWidget,
)

// GOOD - Or use color opacity where possible
Container(
  color: Colors.black.withOpacity(0.5),
)
```

### Widgets That Use saveLayer

Avoid or minimize:
- `Opacity` with non-trivial children
- `ColorFiltered`
- `ShaderMask`
- Complex `ClipPath` operations
- `BackdropFilter`

### Use FadeText Instead of Animated Opacity

```dart
// BAD
AnimatedOpacity(
  opacity: visible ? 1.0 : 0.0,
  child: Text('Hello'),
)

// GOOD
FadeText(
  text: 'Hello',
  startFrame: 30,
  fadeInFrames: 20,
)
```

### Clear Image Cache

```dart
// Between renders or scenes
imageCache.clear();
imageCache.clearLiveImages();
```

---

## Widget Optimization

### Minimize Widget Rebuilds

```dart
// BAD - Creates new TextStyle every frame
TimeConsumer(
  builder: (context, frame, _) {
    return Text(
      'Frame: $frame',
      style: TextStyle(fontSize: 24),  // New instance each frame
    );
  },
)

// GOOD - Reuse constant styles
const _textStyle = TextStyle(fontSize: 24);

TimeConsumer(
  builder: (context, frame, _) {
    return Text(
      'Frame: $frame',
      style: _textStyle,  // Reused
    );
  },
)
```

### Avoid Unnecessary Animation Calculations

```dart
// BAD - Calculates even when not needed
TimeConsumer(
  builder: (context, frame, _) {
    final progress = frame / 100;  // Always calculated
    final opacity = progress.clamp(0.0, 1.0);
    final scale = 1.0 + progress * 0.5;
    final rotation = progress * 2 * pi;

    return Transform(
      transform: Matrix4.identity()
        ..scale(scale)
        ..rotateZ(rotation),
      child: Opacity(
        opacity: opacity,
        child: content,
      ),
    );
  },
)

// GOOD - Only calculate when animating
TimeConsumer(
  builder: (context, frame, _) {
    // Skip calculation if animation complete
    if (frame >= 100) {
      return content;  // Static content
    }

    final progress = frame / 100;
    // ... animation logic
  },
)
```

### Use const Widgets

```dart
// BAD
Widget build(BuildContext context) {
  return Container(
    color: Colors.black,
    child: Center(
      child: Text('Static'),
    ),
  );
}

// GOOD
Widget build(BuildContext context) {
  return const Container(
    color: Colors.black,
    child: Center(
      child: Text('Static'),
    ),
  );
}
```

### Flatten Deep Widget Trees

```dart
// BAD - Deep nesting
Center(
  child: Padding(
    padding: EdgeInsets.all(20),
    child: Container(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text('Title'),
          ),
        ],
      ),
    ),
  ),
)

// GOOD - Flatter structure
VCenter(
  child: VPadding(
    padding: EdgeInsets.all(20),
    child: VColumn(
      spacing: 10,
      children: [
        Text('Title'),
      ],
    ),
  ),
)
```

---

## Media Optimization

### Match Image Resolution to Output

```dart
// Output: 1080x1920
// Don't use 4K images!

// Pre-scale images to target resolution
// 1080p image = ~2MB vs 4K image = ~8MB
```

### Use Appropriate Image Formats

| Format | Use Case | Size |
|--------|----------|------|
| JPEG | Photos | Smaller |
| PNG | Graphics, transparency | Larger |
| WebP | Both (if supported) | Smallest |

### Pre-Trim Videos

```bash
# Trim externally before using in Fluvie
ffmpeg -i long_video.mp4 -ss 00:00:30 -t 00:00:10 -c copy trimmed.mp4
```

### Optimize Audio Files

```bash
# Convert to efficient format
ffmpeg -i audio.wav -acodec libmp3lame -q:a 4 audio.mp3
```

### Limit Video Resolution

```dart
// For embedded videos, consider using lower resolution
// 720p is often sufficient for PiP or backgrounds
```

---

## Profiling

### Time Individual Renders

```dart
final stopwatch = Stopwatch()..start();

await RenderService.execute(
  composition: video,
  outputPath: 'output.mp4',
  onProgress: (p) {
    if (p > 0) {
      final elapsed = stopwatch.elapsedMilliseconds;
      final estimatedTotal = elapsed / p;
      print('Estimated total time: ${estimatedTotal / 1000}s');
    }
  },
);

print('Render completed in ${stopwatch.elapsed}');
```

### Profile Frame Capture

```dart
int slowFrames = 0;
const slowThreshold = Duration(milliseconds: 100);

await RenderService.execute(
  composition: video,
  outputPath: 'output.mp4',
  onFrameCapture: (frame, _) {
    final duration = captureTimer.elapsed;
    captureTimer.reset();

    if (duration > slowThreshold) {
      slowFrames++;
      print('Slow frame $frame: ${duration.inMilliseconds}ms');
    }
  },
);

print('Slow frames: $slowFrames');
```

### Identify Heavy Scenes

```dart
// Render scenes individually to find slow ones
for (var i = 0; i < scenes.length; i++) {
  final stopwatch = Stopwatch()..start();

  await RenderService.execute(
    composition: Video(scenes: [scenes[i]], ...),
    outputPath: 'scene_$i.mp4',
  );

  print('Scene $i: ${stopwatch.elapsed}');
}
```

---

## Quick Reference

### Do

- Use `Fade` widgets instead of `Opacity`
- Match media resolution to output
- Use `const` widgets where possible
- Pre-trim video files
- Clear caches between renders
- Test at lower resolution first

### Don't

- Use `saveLayer`-heavy widgets excessively
- Load 4K images for 1080p output
- Create new objects in `TimeConsumer` builders
- Forget to clear image cache
- Use WAV files when MP3 suffices

### Performance Checklist

- [ ] Preview quality for testing
- [ ] Images sized appropriately
- [ ] Videos pre-trimmed
- [ ] No unnecessary `Opacity` widgets
- [ ] Cache cleared between renders
- [ ] Profiled to find bottlenecks

---

## Related

- [Encoding Settings](encoding-settings.md)
- [Custom Render Pipeline](custom-render-pipeline.md)
- [Frame Extraction](frame-extraction.md)
- [Concept: Rendering Pipeline](../concept/rendering-pipeline.md)
