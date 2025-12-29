# Optimizing Large Compositions

Techniques to improve render speed and reduce resource usage for complex video compositions.

## Problem

Large or complex compositions render slowly, consume excessive memory, or cause crashes.

## Solutions

### 1. Reduce Resolution

Render at lower resolution, upscale if needed:

```dart
VideoComposition(
  width: 1280,  // 720p instead of 1080p
  height: 720,
  // Renders ~2x faster than 1920x1080
)
```

### 2. Lower Frame Rate

Reduce FPS for smoother rendering:

```dart
VideoComposition(
  fps: 24,  // Instead of 30 or 60
  // 24fps is ~20% faster than 30fps
)
```

### 3. Optimize Widget Rebuilds

Use `const` widgets where possible:

```dart
// Bad: Creates new widget every frame
Layer(
  child: TimeConsumer(
    builder: (context, frame, progress) {
      return Container(  // Rebuilt every frame
        color: Colors.blue,
        child: Text('Static Text'),  // Rebuilt unnecessarily
      );
    },
  ),
)

// Good: Reuse const widgets
const staticContent = Text('Static Text');

Layer(
  child: TimeConsumer(
    builder: (context, frame, progress) {
      return Container(
        color: Colors.blue,
        child: staticContent,  // Reused, not rebuilt
      );
    },
  ),
)
```

### 4. Minimize Layer Count

Combine layers when possible:

```dart
// Less efficient: Many layers
LayerStack(
  children: [
    Layer(child: Background()),
    Layer(child: Element1()),
    Layer(child: Element2()),
    Layer(child: Element3()),
  ],
)

// More efficient: Combine static elements
LayerStack(
  children: [
    Layer(
      child: Stack(
        children: [
          Background(),
          Element1(),
          Element2(),
          Element3(),
        ],
      ),
    ),
  ],
)
```

### 5. Use Simpler Effects

Avoid expensive operations:

```dart
// Expensive: Blur and gradients every frame
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(...),
  ),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
    child: YourContent(),
  ),
)

// Cheaper: Solid colors, pre-rendered assets
Container(
  color: Colors.blue,
  child: Image.asset('pre-blurred-background.png'),
)
```

### 6. Optimize Image Assets

```dart
// Bad: Load large image every frame
Image.asset('large-image.png')

// Good: Use appropriately sized assets
// - Resize images to exact display size
// - Use WebP format for smaller files
// - Cache decoded images
Image.asset(
  'optimized-image.webp',
  cacheWidth: 1920,  // Match composition width
)
```

### 7. Render in Segments

For very long videos, render in chunks:

```dart
// Render first 300 frames
await renderService.execute(
  config: config.copyWith(
    timeline: config.timeline.copyWith(
      startFrame: 0,
      durationInFrames: 300,
    ),
  ),
  // ...
);

// Render next 300 frames
await renderService.execute(
  config: config.copyWith(
    timeline: config.timeline.copyWith(
      startFrame: 300,
      durationInFrames: 300,
    ),
  ),
  // ...
);

// Concatenate segments with FFmpeg
```

## Performance Benchmarks

| Optimization | Render Time Improvement |
|--------------|-------------------------|
| 1080p → 720p | ~2x faster |
| 30fps → 24fps | ~20% faster |
| Reduce layers | ~10-30% faster |
| Simpler effects | ~10-50% faster |
| Optimized images | ~5-15% faster |

## Memory Optimization

### Monitor Memory Usage

```dart
int frameCount = 0;
await renderService.execute(
  // ...
  onFrameUpdate: (frame) {
    frameCount++;
    if (frameCount % 30 == 0) {
      // Log memory every second
      print('Memory: ${ProcessInfo.currentRss ~/ 1024 ~/ 1024} MB');
    }
  },
);
```

### Clear Caches

```dart
// Clear image cache between renders
imageCache.clear();
imageCache.clearLiveImages();
```

## Tips

1. **Profile first**: Identify bottlenecks before optimizing
2. **Test incrementally**: Optimize one thing at a time
3. **Balance quality vs speed**: Find acceptable trade-offs
4. **Use appropriate formats**: WebP for images, H.264 for video
5. **Monitor resources**: Watch memory and CPU during renders

## Related

- [Reducing Memory Usage](memory-optimization.md)
- [Fast Preview Rendering](preview-optimization.md)
- [Performance Benchmarks](../performance/benchmarks.md)
