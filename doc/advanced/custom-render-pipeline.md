# Custom Render Pipeline

> **Customizing the rendering process**

For advanced use cases, Fluvie allows you to customize various aspects of the rendering pipeline.

## Table of Contents

- [Overview](#overview)
- [RenderService](#renderservice)
- [Progress Tracking](#progress-tracking)
- [Custom Frame Processing](#custom-frame-processing)
- [Batch Rendering](#batch-rendering)
- [Integration Patterns](#integration-patterns)

---

## Overview

The rendering pipeline consists of:

1. **Frame Sequencing**: Capturing each frame as an image
2. **Frame Processing**: Optional post-processing
3. **Video Encoding**: FFmpeg assembles frames into video
4. **Audio Mixing**: Audio tracks are mixed in

You can customize each stage for specific needs.

---

## RenderService

The `RenderService` class orchestrates rendering:

```dart
await RenderService.execute(
  composition: video,
  outputPath: 'output.mp4',
  settings: EncodingConfig.standard(),
  tester: tester,  // WidgetTester in test environment
  onProgress: (progress) {
    print('Rendering: ${(progress * 100).toStringAsFixed(1)}%');
  },
);
```

### Execute Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `composition` | `Video` | The video composition to render |
| `outputPath` | `String` | Output file path |
| `settings` | `EncodingConfig` | Encoding configuration |
| `tester` | `WidgetTester` | Flutter test helper |
| `onProgress` | `Function(double)?` | Progress callback (0.0-1.0) |
| `onFrameCapture` | `Function(int, Uint8List)?` | Per-frame callback |

---

## Progress Tracking

### Basic Progress

```dart
await RenderService.execute(
  composition: video,
  outputPath: 'output.mp4',
  onProgress: (progress) {
    final percent = (progress * 100).toStringAsFixed(1);
    print('Progress: $percent%');
  },
);
```

### Detailed Progress

```dart
int currentFrame = 0;
final totalFrames = video.totalFrames;

await RenderService.execute(
  composition: video,
  outputPath: 'output.mp4',
  onProgress: (progress) {
    currentFrame = (progress * totalFrames).round();

    // Estimate time remaining
    final elapsed = stopwatch.elapsedMilliseconds;
    final framesRemaining = totalFrames - currentFrame;
    final msPerFrame = elapsed / currentFrame;
    final estimatedRemaining = Duration(
      milliseconds: (framesRemaining * msPerFrame).round(),
    );

    print('Frame $currentFrame/$totalFrames - ETA: $estimatedRemaining');
  },
);
```

### UI Progress

```dart
class RenderProgressWidget extends StatefulWidget {
  final Video video;
  final String outputPath;

  @override
  State<RenderProgressWidget> createState() => _RenderProgressWidgetState();
}

class _RenderProgressWidgetState extends State<RenderProgressWidget> {
  double _progress = 0.0;
  bool _isRendering = false;

  Future<void> _startRender() async {
    setState(() => _isRendering = true);

    await RenderService.execute(
      composition: widget.video,
      outputPath: widget.outputPath,
      onProgress: (progress) {
        setState(() => _progress = progress);
      },
    );

    setState(() => _isRendering = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LinearProgressIndicator(value: _progress),
        Text('${(_progress * 100).toStringAsFixed(0)}%'),
        ElevatedButton(
          onPressed: _isRendering ? null : _startRender,
          child: Text(_isRendering ? 'Rendering...' : 'Start Render'),
        ),
      ],
    );
  }
}
```

---

## Custom Frame Processing

### Per-Frame Callback

Access each frame as it's captured:

```dart
await RenderService.execute(
  composition: video,
  outputPath: 'output.mp4',
  onFrameCapture: (frameNumber, imageBytes) {
    // imageBytes is PNG or raw RGBA data

    // Example: Save specific frames
    if (frameNumber % 30 == 0) {
      File('thumbnails/frame_$frameNumber.png')
        .writeAsBytesSync(imageBytes);
    }
  },
);
```

### Frame Transformation

For custom frame processing, you can:

1. Capture frames to a temp directory
2. Process frames with custom code
3. Encode processed frames

```dart
// Step 1: Capture frames
final tempDir = await Directory.systemTemp.createTemp('frames_');

await RenderService.execute(
  composition: video,
  outputPath: tempDir.path,  // Output to directory
  settings: EncodingConfig(
    debugOutputFrames: true,  // Save individual frames
    frameFormat: FrameFormat.png,
  ),
);

// Step 2: Process frames
for (final file in tempDir.listSync().whereType<File>()) {
  final image = img.decodeImage(file.readAsBytesSync())!;

  // Apply custom processing
  final processed = applyCustomFilter(image);

  file.writeAsBytesSync(img.encodePng(processed));
}

// Step 3: Encode processed frames
await FFmpegService.encodeFrames(
  inputPath: '${tempDir.path}/frame_%04d.png',
  outputPath: 'output.mp4',
  fps: 30,
);
```

---

## Batch Rendering

### Sequential Batch

```dart
Future<void> renderBatch(List<VideoConfig> configs) async {
  for (var i = 0; i < configs.length; i++) {
    final config = configs[i];
    print('Rendering ${i + 1}/${configs.length}: ${config.name}');

    final video = createVideo(config);

    await RenderService.execute(
      composition: video,
      outputPath: 'output/${config.name}.mp4',
      onProgress: (p) => print('  ${(p * 100).toStringAsFixed(0)}%'),
    );
  }
}
```

### Parallel Batch (Advanced)

For multi-core systems, render in parallel:

```dart
import 'dart:isolate';

Future<void> renderParallel(List<VideoConfig> configs) async {
  final futures = configs.map((config) async {
    // Each render in separate isolate
    await Isolate.run(() async {
      final video = createVideo(config);
      await RenderService.execute(
        composition: video,
        outputPath: 'output/${config.name}.mp4',
      );
    });
  });

  await Future.wait(futures);
}
```

---

## Integration Patterns

### CI/CD Integration

```dart
// ci_render.dart
void main() async {
  final video = createVideo();

  final stopwatch = Stopwatch()..start();

  await RenderService.execute(
    composition: video,
    outputPath: 'output/video.mp4',
    settings: EncodingConfig(quality: RenderQuality.high),
    onProgress: (p) {
      // CI-friendly progress
      print('##[progress]${(p * 100).round()}');
    },
  );

  print('Render completed in ${stopwatch.elapsed}');
  exit(0);
}
```

### API Integration

```dart
// Render as a service
class RenderController {
  Future<String> renderVideo(RenderRequest request) async {
    final video = buildVideoFromRequest(request);
    final outputPath = '${tempDir}/${uuid()}.mp4';

    await RenderService.execute(
      composition: video,
      outputPath: outputPath,
      onProgress: (p) {
        // Update job status in database
        updateJobProgress(request.jobId, p);
      },
    );

    // Upload to storage
    final url = await uploadToStorage(outputPath);

    // Cleanup
    File(outputPath).deleteSync();

    return url;
  }
}
```

### Queue-Based Rendering

```dart
class RenderQueue {
  final _queue = <RenderJob>[];
  bool _isProcessing = false;

  void enqueue(RenderJob job) {
    _queue.add(job);
    _processNext();
  }

  Future<void> _processNext() async {
    if (_isProcessing || _queue.isEmpty) return;
    _isProcessing = true;

    final job = _queue.removeAt(0);
    job.status = JobStatus.rendering;

    try {
      await RenderService.execute(
        composition: job.video,
        outputPath: job.outputPath,
        onProgress: (p) => job.progress = p,
      );
      job.status = JobStatus.completed;
    } catch (e) {
      job.status = JobStatus.failed;
      job.error = e.toString();
    }

    _isProcessing = false;
    _processNext();
  }
}
```

---

## Error Handling

### Graceful Error Recovery

```dart
Future<void> renderWithRetry(Video video, String outputPath) async {
  const maxRetries = 3;

  for (var attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      await RenderService.execute(
        composition: video,
        outputPath: outputPath,
      );
      return;  // Success
    } catch (e) {
      print('Render attempt $attempt failed: $e');

      if (attempt == maxRetries) {
        throw RenderException('Failed after $maxRetries attempts: $e');
      }

      // Wait before retry
      await Future.delayed(Duration(seconds: attempt * 2));
    }
  }
}
```

### Cleanup on Failure

```dart
Future<void> renderSafely(Video video, String outputPath) async {
  final tempFramesDir = await Directory.systemTemp.createTemp('render_');

  try {
    await RenderService.execute(
      composition: video,
      outputPath: outputPath,
      settings: EncodingConfig(
        tempDirectory: tempFramesDir.path,
      ),
    );
  } finally {
    // Always cleanup temp files
    if (await tempFramesDir.exists()) {
      await tempFramesDir.delete(recursive: true);
    }
  }
}
```

---

## Related

- [Encoding Settings](encoding-settings.md)
- [Frame Extraction](frame-extraction.md)
- [ONLY_SERVER_MODE](../ONLY_SERVER_MODE.md)
- [Performance Tips](performance-tips.md)
