# VideoComposition

> **Low-level composition root for full control**

`VideoComposition` is the foundation widget that powers Fluvie's video rendering. It provides direct access to the frame-based rendering system without the scene abstraction.

## Table of Contents

- [Overview](#overview)
- [Properties](#properties)
- [Examples](#examples)
- [When to Use](#when-to-use)
- [Comparison with Video](#comparison-with-video)
- [Related](#related)

---

## Overview

`VideoComposition` is the low-level API for creating video compositions. Unlike `Video`, it doesn't provide scene management or transitions - you have full control over timing and structure.

```dart
import 'package:fluvie/fluvie.dart';

VideoComposition(
  fps: 30,
  durationInFrames: 150,
  width: 1920,
  height: 1080,
  child: TimeConsumer(
    builder: (context, frame, progress) {
      return MyAnimatedContent(progress: progress);
    },
  ),
)
```

### Key Differences from Video

| Aspect | VideoComposition | Video |
|--------|------------------|-------|
| Scene management | Manual | Automatic |
| Transitions | Manual | Built-in |
| Background music | Manual AudioTrack | Simple properties |
| API style | Imperative | Declarative |
| Use case | Custom pipelines | Most videos |

---

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `fps` | `int` | **required** | Frames per second |
| `durationInFrames` | `int` | **required** | Total duration in frames |
| `width` | `int` | `1920` | Output width in pixels |
| `height` | `int` | `1080` | Output height in pixels |
| `child` | `Widget` | **required** | Content widget |
| `encoding` | `EncodingConfig?` | `null` | Quality and format settings |

---

## Examples

### Basic Composition

```dart
VideoComposition(
  fps: 30,
  durationInFrames: 90, // 3 seconds
  width: 1920,
  height: 1080,
  child: Container(
    color: Colors.blue,
    child: Center(
      child: Text(
        'Hello, World!',
        style: TextStyle(fontSize: 72, color: Colors.white),
      ),
    ),
  ),
)
```

### With Frame-Based Animation

```dart
VideoComposition(
  fps: 30,
  durationInFrames: 150,
  width: 1920,
  height: 1080,
  child: TimeConsumer(
    builder: (context, frame, progress) {
      // Animate color from blue to purple
      final color = Color.lerp(
        Colors.blue,
        Colors.purple,
        progress,
      )!;

      // Animate text opacity
      final textOpacity = Curves.easeOut.transform(
        (progress * 2).clamp(0.0, 1.0),
      );

      return Container(
        color: color,
        child: Center(
          child: Opacity(
            opacity: textOpacity,
            child: Text(
              'Frame: $frame',
              style: TextStyle(fontSize: 48, color: Colors.white),
            ),
          ),
        ),
      );
    },
  ),
)
```

### Manual Layering

```dart
VideoComposition(
  fps: 30,
  durationInFrames: 300,
  width: 1920,
  height: 1080,
  child: LayerStack(
    children: [
      // Background layer
      Layer.background(
        child: GradientBackground(),
      ),

      // Content layer with timing
      Layer(
        startFrame: 30,
        endFrame: 270,
        fadeInFrames: 15,
        fadeOutFrames: 15,
        child: MainContent(),
      ),

      // Overlay layer
      Layer.overlay(
        child: ParticleEffect.sparkles(),
      ),
    ],
  ),
)
```

### With Audio

```dart
VideoComposition(
  fps: 30,
  durationInFrames: 300,
  width: 1920,
  height: 1080,
  child: BackgroundAudio(
    source: AudioSource.asset('assets/audio/music.mp3'),
    volume: 0.7,
    fadeInFrames: 30,
    fadeOutFrames: 60,
    child: LayerStack(
      children: [
        // Video content
        Layer(child: Content()),

        // Sound effect at specific frame
        AudioTrack(
          source: AudioSource.asset('assets/audio/whoosh.mp3'),
          startFrame: 60,
          durationInFrames: 30,
          volume: 0.5,
          child: const SizedBox.shrink(),
        ),
      ],
    ),
  ),
)
```

### With Encoding Settings

```dart
VideoComposition(
  fps: 30,
  durationInFrames: 300,
  width: 1920,
  height: 1080,
  encoding: const EncodingConfig(
    quality: RenderQuality.high,
    frameFormat: FrameFormat.rawRgba,
    debugFrameOutputPath: 'tmp/debug_frames',
    keepDebugFrames: false,
  ),
  child: Content(),
)
```

---

## When to Use

### Use VideoComposition When:

1. **Building custom render pipelines**
   ```dart
   // Custom frame processing
   VideoComposition(
     child: MyCustomFrameProcessor(),
   )
   ```

2. **Integrating with existing state management**
   ```dart
   // Using your own state
   VideoComposition(
     child: Consumer<MyState>(
       builder: (context, state, _) => AnimatedContent(state: state),
     ),
   )
   ```

3. **Creating reusable animation components**
   ```dart
   // Standalone animation widget
   class MyReusableAnimation extends StatelessWidget {
     @override
     Widget build(BuildContext context) {
       return VideoComposition(
         fps: 30,
         durationInFrames: 60,
         width: 400,
         height: 400,
         child: MyAnimation(),
       );
     }
   }
   ```

4. **Testing or prototyping frame-based logic**
   ```dart
   // Quick frame test
   VideoComposition(
     fps: 30,
     durationInFrames: 30,
     child: TimeConsumer(
       builder: (_, frame, _) => Text('Frame: $frame'),
     ),
   )
   ```

### Use Video Instead When:

- Building scene-based videos
- Want automatic transitions
- Need simple background music
- Prefer declarative API

---

## Comparison with Video

### Equivalent Code

**Using Video:**
```dart
Video(
  fps: 30,
  width: 1920,
  height: 1080,
  scenes: [
    Scene(
      durationInFrames: 90,
      background: Background.solid(Colors.blue),
      children: [
        VCenter(child: Text('Hello')),
      ],
    ),
  ],
)
```

**Using VideoComposition:**
```dart
VideoComposition(
  fps: 30,
  durationInFrames: 90,
  width: 1920,
  height: 1080,
  child: Stack(
    children: [
      Container(color: Colors.blue),
      Center(child: Text('Hello')),
    ],
  ),
)
```

### Converting Between APIs

```dart
// Video internally creates a VideoComposition
// You can think of Video as syntactic sugar for:

VideoComposition(
  fps: video.fps,
  durationInFrames: _calculateTotalDuration(video.scenes),
  width: video.width,
  height: video.height,
  child: _buildSceneStack(video.scenes, video.defaultTransition),
)
```

---

## Working with RenderService

VideoComposition works directly with `RenderService`:

```dart
testWidgets('Render video', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: VideoComposition(
          fps: 30,
          durationInFrames: 90,
          width: 1920,
          height: 1080,
          child: MyContent(),
        ),
      ),
    ),
  );

  final context = tester.element(find.byType(VideoComposition));
  final renderService = RenderService();

  // Create config from widget tree
  final config = renderService.createConfigFromContext(context);

  // Execute render
  await renderService.execute(
    context: context,
    outputPath: 'output/video.mp4',
    onFrameUpdate: (frame) async {
      await tester.pump();
    },
  );
});
```

---

## Accessing Composition Data

### VideoCompositionData

Child widgets can access composition settings:

```dart
VideoComposition(
  fps: 30,
  durationInFrames: 90,
  width: 1920,
  height: 1080,
  child: Builder(
    builder: (context) {
      final data = VideoCompositionData.of(context);

      if (data != null) {
        print('FPS: ${data.fps}');
        print('Duration: ${data.durationInFrames}');
        print('Size: ${data.width}x${data.height}');
      }

      return Content();
    },
  ),
)
```

### FrameProvider

Access current frame from anywhere in the tree:

```dart
Builder(
  builder: (context) {
    final frameProvider = FrameProvider.of(context);
    final currentFrame = frameProvider?.frame ?? 0;

    return Text('Frame: $currentFrame');
  },
)
```

---

## Related

- [Video](video.md) - High-level declarative API
- [TimeConsumer](time-consumer.md) - Frame-based animation
- [LayerStack](../layout/layer-stack.md) - Layer composition
- [RenderService](../../advanced/custom-render-pipeline.md) - Rendering
