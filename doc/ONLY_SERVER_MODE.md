# Server-Only Rendering Mode

> **Render Fluvie videos without a Flutter UI**

This guide explains how to render Fluvie videos in a server or headless environment, without running a Flutter application with a visible UI. This is useful for:

- Automated video generation pipelines
- CI/CD workflows
- Backend services that generate videos on-demand
- Batch processing of video templates

## Table of Contents

- [Current Approach](#current-approach)
- [How It Works](#how-it-works)
- [Complete Example](#complete-example)
- [CI/CD Integration](#cicd-integration)
- [Limitations](#limitations)
- [Future Improvements](#future-improvements)

---

## Current Approach

Fluvie currently supports server-only rendering through Flutter's **test framework**. The test framework provides a headless rendering environment that can pump widgets and capture frames without displaying a window.

### Key Components

1. **Flutter Test Framework** - Provides `WidgetTester` for headless widget pumping
2. **RenderService** - Orchestrates frame capture and encoding
3. **FFmpeg** - Encodes captured frames into video

---

## How It Works

The server-only rendering process follows these steps:

```
1. Create a testable widget composition
2. Use WidgetTester to pump the widget tree
3. RenderService captures each frame from a RepaintBoundary
4. Frames are streamed to FFmpeg for encoding
5. Final video file is written to disk
```

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter Test Environment              │
│  ┌─────────────────┐       ┌─────────────────────────┐  │
│  │  WidgetTester   │──────▶│   Widget Tree           │  │
│  │  (pumps frames) │       │   (VideoComposition)    │  │
│  └─────────────────┘       └───────────┬─────────────┘  │
│                                        │                 │
│                            ┌───────────▼─────────────┐  │
│                            │   RepaintBoundary       │  │
│                            │   (frame capture)       │  │
│                            └───────────┬─────────────┘  │
│                                        │                 │
└────────────────────────────────────────┼─────────────────┘
                                         │
                             ┌───────────▼─────────────┐
                             │   FrameSequencer        │
                             │   (raw frame bytes)     │
                             └───────────┬─────────────┘
                                         │
                             ┌───────────▼─────────────┐
                             │   FFmpeg Process        │
                             │   (video encoding)      │
                             └───────────┬─────────────┘
                                         │
                             ┌───────────▼─────────────┐
                             │   Output Video File     │
                             │   (MP4, WebM, etc.)     │
                             └─────────────────────────┘
```

---

## Complete Example

Here's a complete example of rendering a video in a test environment:

### 1. Create the Test File

Create a file like `test/render_video_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

void main() {
  testWidgets('Render my video composition', (WidgetTester tester) async {
    // 1. Define your composition
    final composition = VideoComposition(
      fps: 30,
      durationInFrames: 150, // 5 seconds
      width: 1920,
      height: 1080,
      encoding: const EncodingConfig(
        quality: RenderQuality.high,
        frameFormat: FrameFormat.rawRgba,
      ),
      child: Builder(
        builder: (context) {
          return TimeConsumer(
            builder: (context, frame, progress) {
              return Container(
                color: Color.lerp(Colors.blue, Colors.purple, progress),
                child: Center(
                  child: Text(
                    'Frame $frame',
                    style: const TextStyle(
                      fontSize: 72,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );

    // 2. Build the widget tree
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: composition),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 3. Get the render service
    final context = tester.element(find.byType(VideoComposition));
    final renderService = RenderService();

    // 4. Execute the render
    final outputPath = await renderService.execute(
      context: context,
      outputPath: 'output/my_video.mp4',
      onFrameUpdate: (frame) async {
        // Update the frame and rebuild
        await tester.pump();
      },
      onProgress: (progress) {
        print('Rendering: ${(progress * 100).toStringAsFixed(1)}%');
      },
    );

    print('Video saved to: $outputPath');
    expect(outputPath, isNotNull);
  });
}
```

### 2. Run the Test

```bash
# Run with flutter test
flutter test test/render_video_test.dart

# Or with specific timeout for long videos
flutter test --timeout=none test/render_video_test.dart
```

### Using the Declarative API

For the higher-level `Video` widget:

```dart
testWidgets('Render declarative video', (WidgetTester tester) async {
  final video = Video(
    fps: 30,
    width: 1920,
    height: 1080,
    scenes: [
      Scene(
        durationInFrames: 90,
        background: Background.solid(Colors.indigo),
        children: [
          VCenter(
            child: AnimatedText.slideUpFade(
              'Generated on Server',
              style: const TextStyle(
                fontSize: 64,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      Scene(
        durationInFrames: 60,
        background: Background.gradient(
          colors: {0: Colors.purple, 60: Colors.blue},
        ),
        children: [
          VCenter(
            child: AnimatedText.scaleFade(
              'No UI Required!',
              startScale: 0.5,
              style: const TextStyle(
                fontSize: 72,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ],
  );

  await tester.pumpWidget(MaterialApp(home: Scaffold(body: video)));
  await tester.pumpAndSettle();

  final context = tester.element(find.byType(Video));
  final config = Video.createConfigFromContext(context);

  final renderService = RenderService();
  final outputPath = await renderService.execute(
    context: context,
    outputPath: 'output/declarative_video.mp4',
    onFrameUpdate: (frame) async {
      await tester.pump();
    },
  );

  print('Rendered: $outputPath');
});
```

---

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Generate Video

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  render:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.22.0'
          channel: 'stable'

      - name: Install FFmpeg
        run: sudo apt-get update && sudo apt-get install -y ffmpeg

      - name: Install dependencies
        run: flutter pub get

      - name: Run render test
        run: flutter test test/render_video_test.dart --timeout=none

      - name: Upload video artifact
        uses: actions/upload-artifact@v4
        with:
          name: rendered-video
          path: output/*.mp4
```

### Docker Example

```dockerfile
FROM ghcr.io/cirruslabs/flutter:stable

# Install FFmpeg
RUN apt-get update && apt-get install -y ffmpeg && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy project files
COPY pubspec.* ./
RUN flutter pub get

COPY . .

# Run the render
CMD ["flutter", "test", "test/render_video_test.dart", "--timeout=none"]
```

---

## Limitations

### Current Limitations

1. **Requires Flutter SDK** - The full Flutter SDK must be installed, even for headless rendering.

2. **Test Framework Overhead** - Using the test framework adds some complexity and performance overhead.

3. **Memory Usage** - Long videos with high resolution can consume significant memory during the frame capture process.

4. **Font Loading** - Custom fonts must be properly loaded in the test environment:
   ```dart
   setUpAll(() async {
     final fontLoader = FontLoader('CustomFont');
     fontLoader.addFont(rootBundle.load('assets/fonts/CustomFont.ttf'));
     await fontLoader.load();
   });
   ```

5. **Asset Loading** - Assets must be available in the test environment:
   ```dart
   // In your test file
   TestWidgetsFlutterBinding.ensureInitialized();
   ```

6. **No Hot Reload** - Changes require a full test restart.

### Platform Considerations

| Platform | Support | Notes |
|----------|---------|-------|
| Linux | Full | Best for CI/CD |
| macOS | Full | Development and CI |
| Windows | Full | Requires FFmpeg in PATH |
| Docker | Full | Recommended for production |

---

## Future Improvements

The current test-based approach works but has room for improvement. Here are potential future enhancements:

### 1. Dedicated Headless Renderer

A purpose-built headless rendering engine would eliminate test framework overhead:

```dart
// Proposed API
final renderer = HeadlessFluvieRenderer();

final outputPath = await renderer.render(
  composition: myVideoComposition,
  outputPath: 'output/video.mp4',
  onProgress: (progress) => print('$progress%'),
);
```

**Benefits:**
- No test framework dependency
- Optimized memory management
- Better progress tracking
- Parallel rendering support

### 2. Dart FFI for Native Rendering

Using Dart FFI to call native rendering libraries directly:

```dart
// Proposed architecture
┌─────────────────┐      ┌─────────────────┐
│   Dart Code     │─────▶│   Native FFI    │
│   (composition) │      │   (Skia/Impeller)│
└─────────────────┘      └────────┬────────┘
                                  │
                         ┌────────▼────────┐
                         │   Direct Frame  │
                         │   Output        │
                         └────────┬────────┘
                                  │
                         ┌────────▼────────┐
                         │   FFmpeg        │
                         └─────────────────┘
```

**Benefits:**
- No Flutter SDK required at runtime
- Smaller deployment footprint
- Faster rendering

### 3. Pre-Rendered Template Caching

For template-based videos, pre-render static elements:

```dart
// Proposed API
final template = CachedTemplate.load('my_template');

final video = template.render(
  data: {
    'title': 'My Video',
    'stats': [247, 12, 365],
    'images': ['photo1.jpg', 'photo2.jpg'],
  },
);
```

**Benefits:**
- Faster generation for template-based content
- Reduced memory usage
- Predictable render times

### 4. Distributed Rendering

Split long videos across multiple workers:

```dart
// Proposed API
final cluster = RenderCluster(workers: 4);

final outputPath = await cluster.render(
  composition: longVideoComposition,
  outputPath: 'output/video.mp4',
);
```

**Benefits:**
- Linear speedup with worker count
- Handle very long videos
- Cloud-native architecture

### 5. Render-as-a-Service

Cloud-based rendering API:

```dart
// Proposed API
final client = FluvieCloudClient(apiKey: 'xxx');

final job = await client.render(
  composition: myVideoComposition,
  quality: RenderQuality.high,
);

final videoUrl = await job.waitForCompletion();
```

**Benefits:**
- No local FFmpeg installation
- Scalable infrastructure
- Pay-per-render pricing

---

## Best Practices

### 1. Optimize for Memory

For long videos, consider rendering in segments:

```dart
final segmentDuration = 300; // 10 seconds at 30fps
final totalFrames = 1800; // 1 minute

for (var start = 0; start < totalFrames; start += segmentDuration) {
  final end = (start + segmentDuration).clamp(0, totalFrames);
  await renderSegment(start, end, 'segment_${start ~/ segmentDuration}.mp4');
}

// Concatenate segments with FFmpeg
await concatenateSegments(outputPath);
```

### 2. Use Raw RGBA Format

For fastest rendering, use raw RGBA instead of PNG:

```dart
VideoComposition(
  encoding: const EncodingConfig(
    frameFormat: FrameFormat.rawRgba, // Faster than PNG
    quality: RenderQuality.high,
  ),
  // ...
)
```

### 3. Warm Up Caches

Pre-load assets before rendering:

```dart
setUpAll(() async {
  // Pre-load images
  await precacheImage(AssetImage('assets/image.png'), context);

  // Pre-load video frames
  final cache = VideoFrameCache();
  await cache.preload('assets/video.mp4', frameCount: 100);
});
```

### 4. Monitor Progress

Track rendering progress for long videos:

```dart
await renderService.execute(
  // ...
  onProgress: (progress) {
    final percent = (progress * 100).toStringAsFixed(1);
    final elapsed = stopwatch.elapsed;
    final estimated = elapsed * (1 / progress);
    final remaining = estimated - elapsed;

    print('Progress: $percent% - ETA: ${remaining.inMinutes}m');
  },
);
```

---

## Related Documentation

- [Rendering Pipeline](concept/rendering-pipeline.md)
- [Encoding Settings](advanced/encoding-settings.md)
- [Performance Tips](advanced/performance-tips.md)
- [CI/CD Examples](contributing/testing.md)
