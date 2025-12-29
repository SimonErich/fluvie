# Preview vs Render Mode

> **Two modes for developing and exporting videos**

Fluvie operates in two distinct modes: **Preview mode** for interactive development, and **Render mode** for final export. Understanding the difference is key to an efficient workflow.

## Table of Contents

- [Overview](#overview)
- [Preview Mode](#preview-mode)
- [Render Mode](#render-mode)
- [How Modes Are Detected](#how-modes-are-detected)
- [Writing Mode-Aware Widgets](#writing-mode-aware-widgets)
- [Best Practices](#best-practices)

---

## Overview

| Aspect | Preview Mode | Render Mode |
|--------|--------------|-------------|
| **Purpose** | Development & review | Final export |
| **Speed** | Real-time playback | As fast as possible |
| **Frames** | May skip frames | Every frame captured |
| **Audio** | Plays through speakers | Mixed by FFmpeg |
| **Quality** | Screen resolution | Target resolution |
| **Async** | Immediate | Waits for completion |

```
┌───────────────────────────────────────────────────────────────┐
│                      Your Fluvie App                           │
│                                                                │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                    Preview Mode                          │  │
│  │                                                          │  │
│  │  • Run flutter app                                       │  │
│  │  • See changes instantly (hot reload)                    │  │
│  │  • Hear audio playback                                   │  │
│  │  • Scrub through timeline                                │  │
│  │                                                          │  │
│  └─────────────────────────────────────────────────────────┘  │
│                            │                                   │
│                            │ Happy with result?                │
│                            ▼                                   │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                    Render Mode                           │  │
│  │                                                          │  │
│  │  • Export to video file                                  │  │
│  │  • Every frame captured                                  │  │
│  │  • Audio mixed precisely                                 │  │
│  │  • Full resolution output                                │  │
│  │                                                          │  │
│  └─────────────────────────────────────────────────────────┘  │
│                            │                                   │
│                            ▼                                   │
│                     output.mp4                                 │
│                                                                │
└───────────────────────────────────────────────────────────────┘
```

---

## Preview Mode

Preview mode is your development environment. It's designed for rapid iteration and instant feedback.

### Characteristics

1. **Real-Time Playback**
   - Video plays at the specified FPS (30fps = real-time 30fps)
   - If rendering can't keep up, frames are skipped

2. **Audio Playback**
   - Audio plays through your device speakers
   - Uses the `just_audio` package for playback
   - Synchronized with visual timeline

3. **Hot Reload Support**
   - Change code, see updates instantly
   - No need to re-render entire video

4. **Interactive Controls**
   - Play/pause
   - Scrub to specific frame
   - Adjust playback speed

### Using Preview Mode

Simply run your Flutter app:

```bash
flutter run
```

Your video composition widget will play in preview mode automatically:

```dart
class MyVideoPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Video(
        fps: 30,
        width: 1920,
        height: 1080,
        scenes: [
          Scene(
            durationInFrames: 90,
            children: [/* ... */],
          ),
        ],
      ),
    );
  }
}
```

### Preview Controls

Add playback controls to your preview:

```dart
class MyVideoPage extends StatefulWidget {
  @override
  State<MyVideoPage> createState() => _MyVideoPageState();
}

class _MyVideoPageState extends State<MyVideoPage> {
  final _controller = RenderController();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Video(
            controller: _controller,
            fps: 30,
            scenes: [/* ... */],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.play_arrow),
              onPressed: () => _controller.play(),
            ),
            IconButton(
              icon: Icon(Icons.pause),
              onPressed: () => _controller.pause(),
            ),
            Slider(
              value: _controller.currentFrame.toDouble(),
              max: _controller.totalFrames.toDouble(),
              onChanged: (value) => _controller.seekTo(value.toInt()),
            ),
          ],
        ),
      ],
    );
  }
}
```

### Platform Support for Audio Preview

| Platform | Audio Support |
|----------|---------------|
| macOS | Full |
| Windows | Full |
| Linux | Limited (just_audio limitations) |
| Web | Full |
| iOS/Android | Full |

---

## Render Mode

Render mode is for producing the final video file. It's designed for quality and accuracy.

### Characteristics

1. **Deterministic Frame Capture**
   - Every single frame is captured
   - No frames are ever skipped
   - Rendering waits as long as needed for each frame

2. **Exact Resolution**
   - Output matches specified width/height exactly
   - Proper pixel ratio handling

3. **Audio Mixing**
   - Audio is mixed by FFmpeg, not played back
   - Precise frame-accurate synchronization
   - Multiple tracks combined with fades and volume

4. **Async Operation Handling**
   - Waits for embedded video frames to load
   - Waits for network images
   - Ensures all async operations complete before capture

### Triggering Render Mode

#### From Your App

Add a render button:

```dart
ElevatedButton(
  child: Text('Export Video'),
  onPressed: () async {
    final renderService = RenderService();
    final outputPath = await renderService.execute(
      context: context,
      outputPath: 'output/my_video.mp4',
      onFrameUpdate: (frame) async {
        // In a real app, you'd update the widget state
        setState(() => _currentFrame = frame);
        await Future.delayed(Duration(milliseconds: 16));
      },
      onProgress: (progress) {
        print('Rendering: ${(progress * 100).toStringAsFixed(1)}%');
      },
    );
    print('Saved to: $outputPath');
  },
)
```

#### From Tests (Server Mode)

```dart
testWidgets('Render my video', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MyVideoComposition(),
      ),
    ),
  );

  final context = tester.element(find.byType(VideoComposition));
  final renderService = RenderService();

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

## How Modes Are Detected

Fluvie uses `RenderModeProvider` to communicate the current mode to widgets:

```dart
class RenderModeProvider extends InheritedWidget {
  final bool isRendering;

  static bool isRenderMode(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<RenderModeProvider>();
    return provider?.isRendering ?? false;
  }
}
```

### The FrameReadyNotifier

In render mode, async operations must complete before frame capture. The `FrameReadyNotifier` tracks pending operations:

```dart
class FrameReadyNotifier {
  int _pendingOperations = 0;

  void markPending() => _pendingOperations++;
  void markReady() => _pendingOperations--;

  Future<void> waitUntilReady() async {
    while (_pendingOperations > 0) {
      await Future.delayed(Duration(milliseconds: 1));
    }
  }
}
```

---

## Writing Mode-Aware Widgets

Some widgets need to behave differently in each mode.

### Example: EmbeddedVideo

The `EmbeddedVideo` widget handles async frame loading differently:

```dart
class EmbeddedVideo extends StatefulWidget {
  @override
  State<EmbeddedVideo> createState() => _EmbeddedVideoState();
}

class _EmbeddedVideoState extends State<EmbeddedVideo> {
  ui.Image? _currentFrame;

  @override
  Widget build(BuildContext context) {
    final isRendering = RenderModeProvider.isRenderMode(context);

    return TimeConsumer(
      builder: (context, frame, _) {
        if (isRendering) {
          // In render mode: mark pending, load frame, mark ready
          _loadFrameForRender(frame);
        } else {
          // In preview mode: best-effort frame loading
          _loadFrameForPreview(frame);
        }

        return _currentFrame != null
            ? RawImage(image: _currentFrame)
            : placeholder;
      },
    );
  }

  void _loadFrameForRender(int frame) {
    final notifier = FrameReadyNotifier.of(context);
    notifier?.markPending();

    _loadFrame(frame).then((_) {
      notifier?.markReady();
    });
  }

  void _loadFrameForPreview(int frame) {
    // Don't block, just load when ready
    _loadFrame(frame);
  }
}
```

### Example: Conditional Audio

```dart
class AudioPlayback extends StatelessWidget {
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isRendering = RenderModeProvider.isRenderMode(context);

    if (isRendering) {
      // In render mode: audio is handled by FFmpeg
      // Don't play anything locally
      return child;
    }

    // In preview mode: play audio for feedback
    return AudioPreviewPlayer(
      child: child,
    );
  }
}
```

---

## Best Practices

### 1. Develop in Preview, Export in Render

```dart
// During development
flutter run  // Preview mode - fast iteration

// When ready to export
flutter test test/render_test.dart  // Render mode - perfect output
```

### 2. Test Both Modes

Make sure your composition looks correct in both:

```dart
// Visual check in preview
flutter run

// Automated render test
testWidgets('Video renders correctly', (tester) async {
  // Set up and render
  // Assert on output file
});
```

### 3. Handle Async Gracefully

Don't assume network requests complete instantly:

```dart
// Bad: assumes image is loaded
Image.network('https://example.com/image.jpg')

// Good: handles loading state
CachedNetworkImage(
  imageUrl: 'https://example.com/image.jpg',
  placeholder: (context, url) => ColoredBox(color: Colors.grey),
)
```

### 4. Use Placeholders

Show something while async content loads:

```dart
EmbeddedVideo(
  assetPath: 'assets/video.mp4',
  placeholder: Container(
    color: Colors.black,
    child: Center(child: CircularProgressIndicator()),
  ),
)
```

### 5. Consider Performance Differences

Preview mode may have different performance characteristics:

```dart
TimeConsumer(
  builder: (context, frame, _) {
    final isRendering = RenderModeProvider.isRenderMode(context);

    // Reduce particle count in preview for better performance
    final particleCount = isRendering ? 100 : 30;

    return ParticleEffect(count: particleCount);
  },
)
```

---

## Troubleshooting

### Preview Looks Different from Render

**Cause:** Different resolutions or pixel ratios.

**Solution:** Preview at target resolution:
```dart
SizedBox(
  width: 1920 / 2, // Half size for preview
  height: 1080 / 2,
  child: FittedBox(
    child: SizedBox(
      width: 1920,
      height: 1080,
      child: MyVideoComposition(),
    ),
  ),
)
```

### Audio Doesn't Sync in Preview

**Cause:** Audio preview uses different timing than render.

**Solution:** Trust the render output - audio sync is precise in render mode.

### Frames Look Corrupt in Render

**Cause:** Usually caused by Flutter's `Opacity` widget.

**Solution:** Use Fluvie's fade widgets:
```dart
// Bad
Opacity(opacity: 0.5, child: Text('Hello'))

// Good
Fade(opacity: 0.5, child: FadeText('Hello'))
```

---

## Related Documentation

- [Rendering Pipeline](rendering-pipeline.md) - How frames are captured
- [Server-Only Mode](../ONLY_SERVER_MODE.md) - Headless rendering
- [Performance Tips](../advanced/performance-tips.md) - Optimization
