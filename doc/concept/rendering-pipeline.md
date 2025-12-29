# Rendering Pipeline

> **From Flutter widgets to video file: a frame-by-frame journey**

This page explains exactly how Fluvie transforms your widget tree into a finished video file. Understanding this pipeline helps you write more efficient compositions and debug issues.

## Table of Contents

- [Pipeline Overview](#pipeline-overview)
- [Step 1: Configuration Extraction](#step-1-configuration-extraction)
- [Step 2: FFmpeg Session Setup](#step-2-ffmpeg-session-setup)
- [Step 3: Frame Loop](#step-3-frame-loop)
- [Step 4: Encoding and Output](#step-4-encoding-and-output)
- [Performance Considerations](#performance-considerations)

---

## Pipeline Overview

The complete rendering pipeline:

```
┌────────────────────────────────────────────────────────────────────┐
│  Your Code                                                          │
│  ───────────                                                        │
│  Video(                                                             │
│    fps: 30,                                                         │
│    scenes: [Scene(...), Scene(...)],                                │
│  )                                                                  │
└──────────────────────────────┬─────────────────────────────────────┘
                               │
                               ▼
┌────────────────────────────────────────────────────────────────────┐
│  Step 1: Configuration Extraction                                   │
│  ─────────────────────────────────                                  │
│  • Walk widget tree                                                 │
│  • Extract RenderConfig (timeline, sequences, audio)                │
│  • Resolve asset paths                                              │
└──────────────────────────────┬─────────────────────────────────────┘
                               │
                               ▼
┌────────────────────────────────────────────────────────────────────┐
│  Step 2: FFmpeg Session Setup                                       │
│  ────────────────────────────                                       │
│  • Build filter graph                                               │
│  • Start FFmpeg process                                             │
│  • Open stdin pipe for frames                                       │
└──────────────────────────────┬─────────────────────────────────────┘
                               │
                               ▼
┌────────────────────────────────────────────────────────────────────┐
│  Step 3: Frame Loop (for each frame 0 to N)                         │
│  ──────────────────────────────────────────                         │
│  • Update frame number                                              │
│  • Pump widget tree                                                 │
│  • Wait for async operations                                        │
│  • Capture from RepaintBoundary                                     │
│  • Write bytes to FFmpeg stdin                                      │
└──────────────────────────────┬─────────────────────────────────────┘
                               │
                               ▼
┌────────────────────────────────────────────────────────────────────┐
│  Step 4: Encoding and Output                                        │
│  ───────────────────────────                                        │
│  • Close FFmpeg stdin                                               │
│  • Wait for encoding to complete                                    │
│  • Clean up temporary files                                         │
│  • Return output path                                               │
└──────────────────────────────┬─────────────────────────────────────┘
                               │
                               ▼
                        ┌──────────────┐
                        │  output.mp4  │
                        └──────────────┘
```

---

## Step 1: Configuration Extraction

### What Happens

The `RenderService` walks your widget tree and extracts a `RenderConfig`:

```dart
final config = RenderService().createConfigFromContext(context);
```

### The RenderConfig

```dart
RenderConfig(
  timeline: TimelineConfig(
    fps: 30,
    durationInFrames: 270,
    width: 1920,
    height: 1080,
  ),
  sequences: [
    SequenceConfig(
      startFrame: 0,
      durationInFrames: 90,
      type: SequenceType.base,
    ),
    SequenceConfig(
      startFrame: 90,
      durationInFrames: 90,
      type: SequenceType.video,
      videoPath: 'assets/clip.mp4',
    ),
    // ...
  ],
  audioTracks: [
    AudioTrackConfig(
      sourcePath: 'assets/music.mp3',
      startFrame: 0,
      durationInFrames: 270,
      volume: 0.8,
    ),
  ],
  embeddedVideos: [
    EmbeddedVideoConfig(
      assetPath: 'assets/clip.mp4',
      startFrame: 90,
      durationInFrames: 90,
      includeAudio: true,
    ),
  ],
  encoding: EncodingConfig(
    quality: RenderQuality.high,
    frameFormat: FrameFormat.rawRgba,
  ),
)
```

### Asset Resolution

Asset paths are resolved to absolute paths:
- `assets/...` → Copied to temp directory
- `https://...` → Downloaded to temp directory
- `/path/to/file` → Used directly

---

## Step 2: FFmpeg Session Setup

### Building the Filter Graph

The `FFmpegFilterGraphBuilder` creates a complex filter graph:

```
# Video processing
[0:v] fps=30,format=yuv420p [v_out]

# Audio from embedded video
[1:a] atrim=start=0:end=3,afade=t=in:st=0:d=0.5,volume=1.0,adelay=3000|3000 [a_embed_0]

# Background music
[2:a] atrim=start=0:end=9,afade=t=in:st=0:d=1,afade=t=out:st=8:d=1,volume=0.8 [a_track_0]

# Mix all audio
[a_embed_0][a_track_0] amix=inputs=2:duration=longest [a_out]
```

### Starting FFmpeg

The FFmpeg command is constructed and executed:

```bash
ffmpeg -y \
  -f rawvideo -pixel_format rgba -video_size 1920x1080 -framerate 30 -i pipe:0 \
  -i /tmp/clip.mp4 \
  -i /tmp/music.mp3 \
  -filter_complex "[0:v]fps=30,format=yuv420p[v_out];..." \
  -map "[v_out]" -map "[a_out]" \
  -c:v libx264 -preset slow -crf 18 \
  -c:a aac -b:a 192k \
  output.mp4
```

### The Encoding Session

```dart
class VideoEncodingSession {
  final IOSink sink;        // Write frame bytes here
  final Future<void> done;  // Completes when encoding finishes

  void cancel();            // Stop encoding
}
```

---

## Step 3: Frame Loop

This is the heart of the rendering process. For each frame:

### 3.1 Update Frame Number

```dart
onFrameUpdate(currentFrame);
// This triggers TimeConsumer and other frame-dependent widgets to rebuild
```

### 3.2 Pump Widget Tree

In test mode, this uses `WidgetTester`:

```dart
await tester.pump();
// Or in preview mode:
await SchedulerBinding.instance.endOfFrame;
```

### 3.3 Wait for Async Operations

Some widgets have async operations (like loading embedded video frames):

```dart
// FrameReadyNotifier tracks pending operations
await frameReadyNotifier.waitUntilReady();
```

### 3.4 Capture Frame

The `FrameSequencer` captures the frame:

```dart
// Find the RepaintBoundary
final boundary = boundaryKey.currentContext!
    .findRenderObject() as RenderRepaintBoundary;

// Capture at exact dimensions
final image = await boundary.toImage(pixelRatio: pixelRatio);

// Get raw bytes
final byteData = await image.toByteData(format: ImageByteFormat.rawRgba);
final bytes = byteData!.buffer.asUint8List();
```

### 3.5 Handle Dimension Mismatches

If the captured image doesn't match target dimensions:

```dart
// Resize to exact target dimensions
if (capturedWidth != targetWidth || capturedHeight != targetHeight) {
  // Create a new canvas at target size
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);

  // Center the captured image with letterboxing
  canvas.drawColor(Colors.black, BlendMode.src);
  canvas.drawImage(image, centeredOffset, paint);

  // Get the resized image
  final resizedPicture = recorder.endRecording();
  final resizedImage = await resizedPicture.toImage(targetWidth, targetHeight);
}
```

### 3.6 Write to FFmpeg

```dart
session.sink.add(bytes);
```

### Frame Loop Summary

```dart
for (int frame = 0; frame < totalFrames; frame++) {
  // 1. Update widget state
  await onFrameUpdate(frame);

  // 2. Wait for render
  await scheduler.endOfFrame;

  // 3. Wait for async ops
  await frameReadyNotifier.waitUntilReady();

  // 4. Capture
  final bytes = await sequencer.captureFrameRawExact(
    boundaryKey: boundaryKey,
    targetWidth: width,
    targetHeight: height,
    format: frameFormat,
  );

  // 5. Write
  session.sink.add(bytes);

  // Report progress
  onProgress?.call(frame / totalFrames);
}
```

---

## Step 4: Encoding and Output

### Closing the Session

```dart
// Signal end of frame stream
await session.sink.close();

// Wait for FFmpeg to finish encoding
await session.done;
```

### FFmpeg Finalization

FFmpeg:
1. Flushes remaining frames
2. Writes video index
3. Closes output file
4. Exits with status code

### Cleanup

```dart
// Remove temporary files
await tempDir.delete(recursive: true);

// Return output path
return outputPath;
```

---

## Performance Considerations

### Frame Capture Time

The largest bottleneck is usually frame capture:

| Operation | Typical Time |
|-----------|--------------|
| Widget rebuild | 1-5ms |
| Rasterization | 5-20ms |
| toImage() capture | 10-50ms |
| toByteData() | 5-15ms |
| FFmpeg write | 1-2ms |

### Optimizing Capture

1. **Use raw RGBA** instead of PNG:
   ```dart
   encoding: EncodingConfig(
     frameFormat: FrameFormat.rawRgba, // Faster than PNG
   )
   ```

2. **Avoid Flutter's Opacity widget** - use `Fade` widgets instead:
   ```dart
   // Bad: causes saveLayer, rendering artifacts
   Opacity(opacity: 0.5, child: MyWidget())

   // Good: video-safe opacity
   Fade(opacity: 0.5, child: FadeText('Hello'))
   ```

3. **Minimize widget rebuilds**:
   ```dart
   // Bad: rebuilds entire tree every frame
   TimeConsumer(
     builder: (context, frame, _) => HeavyWidget(frame: frame),
   )

   // Good: only rebuild what changes
   TimeConsumer(
     builder: (context, frame, _) => Opacity(
       opacity: frame / 100,
       child: const HeavyWidget(), // const - doesn't rebuild
     ),
   )
   ```

### Memory Management

For long videos, memory can be a concern:

1. **Process in segments** for very long videos
2. **Avoid storing frame history** - each frame is independent
3. **Use debug frame output** only when needed:
   ```dart
   encoding: EncodingConfig(
     debugFrameOutputPath: null, // Don't save debug frames
   )
   ```

### FFmpeg Performance

FFmpeg encoding options affect speed vs quality:

| Preset | Speed | Quality | Use Case |
|--------|-------|---------|----------|
| ultrafast | Fastest | Lowest | Testing |
| veryfast | Very fast | Low | Drafts |
| medium | Balanced | Good | Standard |
| slow | Slow | High | Production |
| veryslow | Slowest | Highest | Final output |

```dart
encoding: EncodingConfig(
  quality: RenderQuality.high, // Uses 'slow' preset
)
```

---

## Debugging the Pipeline

### Debug Frame Output

Save frames as PNG for inspection:

```dart
encoding: EncodingConfig(
  debugFrameOutputPath: 'tmp/debug_frames',
  keepDebugFrames: true,
)
```

### Progress Tracking

Monitor render progress:

```dart
await renderService.execute(
  onProgress: (progress) {
    print('Rendering: ${(progress * 100).toStringAsFixed(1)}%');
  },
);
```

### FFmpeg Logs

Enable verbose logging:

```dart
FluvieConfig.configure(
  logLevel: FluvieLogLevel.debug,
  logModules: {'encoder', 'render'},
);
```

---

## Pipeline Diagram: Single Frame

Detailed view of one frame's journey:

```
┌─────────────────────────────────────────────────────────────────┐
│ Frame 42                                                         │
└─────────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────────┐
│ 1. onFrameUpdate(42)                                             │
│    - RenderController.setFrame(42)                               │
│    - FrameProvider value changes                                 │
│    - TimeConsumer widgets mark dirty                             │
└─────────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. Flutter Build Phase                                           │
│    - Dirty widgets rebuild                                       │
│    - Layout computed                                             │
│    - Paint commands generated                                    │
└─────────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. Flutter Rasterization (Skia/Impeller)                         │
│    - Paint commands executed                                     │
│    - Pixels written to layer                                     │
│    - RepaintBoundary layer complete                              │
└─────────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. FrameReadyNotifier.waitUntilReady()                           │
│    - Check pending async operations                              │
│    - (e.g., embedded video frame loading)                        │
│    - Continue when all ready                                     │
└─────────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. boundary.toImage()                                            │
│    - GPU texture → CPU image                                     │
│    - Resolution: targetWidth × targetHeight                      │
└─────────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6. image.toByteData(format: ImageByteFormat.rawRgba)             │
│    - CPU image → raw bytes                                       │
│    - 1920 × 1080 × 4 = 8,294,400 bytes                           │
└─────────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────────┐
│ 7. session.sink.add(bytes)                                       │
│    - Write to FFmpeg stdin                                       │
│    - FFmpeg queues for encoding                                  │
└─────────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────────┐
│ Frame 42 complete. Next: Frame 43...                             │
└─────────────────────────────────────────────────────────────────┘
```

---

## Related Documentation

- [Architecture](architecture.md) - High-level system design
- [Encoding Settings](../advanced/encoding-settings.md) - Output options
- [Performance Tips](../advanced/performance-tips.md) - Optimization guide
- [Server-Only Mode](../ONLY_SERVER_MODE.md) - Headless rendering
