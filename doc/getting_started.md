# Getting Started with Fluvie

Fluvie allows you to generate videos programmatically using Flutter widgets.

## Installation

Add `fluvie` to your `pubspec.yaml`:

```yaml
dependencies:
  fluvie: ^0.1.0
```

### FFmpeg Setup

Fluvie requires FFmpeg for video encoding. Install it for your platform:

**Linux:**
```bash
sudo apt install ffmpeg
```

**macOS:**
```bash
brew install ffmpeg
```

**Windows:**
Download from [ffmpeg.org](https://ffmpeg.org/download.html) and add to PATH.

**Web:**
Include in your `web/index.html`:
```html
<script src="https://unpkg.com/@ffmpeg/ffmpeg@0.12.6/dist/umd/ffmpeg.js"></script>
<script src="https://unpkg.com/@ffmpeg/util@0.12.1/dist/umd/util.js"></script>
```

## Basic Usage

### 1. Define your composition

Wrap your content in a `VideoComposition` widget. This sets the frame rate, duration, and dimensions.

```dart
import 'package:fluvie/fluvie.dart';

final composition = VideoComposition(
  fps: 30,
  durationInFrames: 150, // 5 seconds
  width: 1920,
  height: 1080,
  child: MyVideoContent(),
);
```

### 2. Create content with Sequences

Use `Sequence` widgets to define time-bounded content blocks:

```dart
class MyVideoContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayerStack(
      children: [
        Sequence(
          startFrame: 0,
          durationInFrames: 60,
          child: Center(child: Text('Scene 1')),
        ),
        Sequence(
          startFrame: 60,
          durationInFrames: 90,
          child: Center(child: Text('Scene 2')),
        ),
      ],
    );
  }
}
```

### 3. Animate using TimeConsumer

Use `TimeConsumer` to access the current frame and progress for animations:

```dart
TimeConsumer(
  builder: (context, frame, progress) {
    // frame: current frame number (0 to durationInFrames-1)
    // progress: normalized progress (0.0 to 1.0)
    return Opacity(
      opacity: progress,
      child: Text('Fading In'),
    );
  },
)
```

### 4. Use interpolate for keyframe animations

The `interpolate` function lets you define complex animations with keyframes:

```dart
TimeConsumer(
  builder: (context, frame, progress) {
    // Move from x=0 to x=200, then back to x=100
    final xPosition = interpolate(
      frame,
      [0, 30, 60],        // keyframes
      [0.0, 200.0, 100.0], // values
      curve: Curves.easeInOut,
    );

    return Transform.translate(
      offset: Offset(xPosition, 0),
      child: MyWidget(),
    );
  },
)
```

### 5. Layer-based composition

Use `LayerStack` and `Layer` for sophisticated compositions with time-based visibility and transitions:

```dart
LayerStack(
  children: [
    // Background layer - always visible, behind everything
    Layer.background(
      fadeInFrames: 15,
      child: GradientBackground(),
    ),

    // Content layer - visible from frame 30 to 120 with fades
    Layer(
      startFrame: 30,
      endFrame: 120,
      fadeInFrames: 15,
      fadeOutFrames: 15,
      child: TitleWidget(),
    ),

    // Overlay layer - always on top
    Layer.overlay(
      blendMode: BlendMode.screen,
      child: Watermark(),
    ),
  ],
)
```

### 6. Add audio

Add background music or sound effects with `AudioTrack`:

```dart
VideoComposition(
  fps: 30,
  durationInFrames: 300,
  child: LayerStack(
    children: [
      // Visual content...
      MyContent(),

      // Audio track
      AudioTrack(
        source: AudioSource.asset('audio/music.mp3'),
        startFrame: 0,
        durationInFrames: 300,
        fadeInFrames: 30,
        fadeOutFrames: 30,
        volume: 0.8,
      ),
    ],
  ),
);
```

## Rendering

Use `RenderService` to export your composition as a video file:

```dart
final renderService = RenderService();

// Get the config from your composition
final config = renderService.createConfigFromContext(compositionContext);

// Execute rendering
final outputPath = await renderService.execute(
  config: config,
  repaintBoundaryKey: boundaryKey,
  onFrameUpdate: (frame) {
    print('Rendering frame $frame / ${config.timeline.durationInFrames}');
  },
);

print('Video saved to: $outputPath');
```

## Architecture

Fluvie uses a "Dual-Engine" architecture:

- **Flutter** renders each frame as a rasterized image using `RepaintBoundary`
- **FFmpeg** encodes the frame sequence into a video file with audio

The rendering process:
1. Flutter widget tree is rebuilt for each frame
2. `FrameSequencer` captures the frame as raw RGBA bytes
3. Bytes are streamed to FFmpeg via stdin
4. FFmpeg processes audio tracks and outputs the final video

See [concept.md](concept.md) for detailed architecture documentation.

## Next Steps

- Explore the [example gallery](../example/) for more complex compositions
- Read the [widget reference](widgets.md) for all available components
- Check [concept.md](concept.md) for architecture deep-dive
