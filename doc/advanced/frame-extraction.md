# Frame Extraction

> **Extracting frames from video files**

Fluvie provides services for extracting frames from video files, useful for thumbnails, previews, and video analysis.

## Table of Contents

- [Overview](#overview)
- [VideoProbeService](#videoprobeservice)
- [FrameExtractionService](#frameextractionservice)
- [VideoFrameCache](#videoframecache)
- [Examples](#examples)
- [Performance Considerations](#performance-considerations)

---

## Overview

Frame extraction involves:

1. **Probing**: Get video metadata (duration, resolution, fps)
2. **Extraction**: Extract specific frames as images
3. **Caching**: Store extracted frames for reuse

```dart
// Get video info
final info = await VideoProbeService.probe('video.mp4');

// Extract a frame
final frame = await FrameExtractionService.extractFrame(
  videoPath: 'video.mp4',
  timestamp: Duration(seconds: 5),
);

// Use cache for efficiency
final cached = await VideoFrameCache.getFrame(
  videoPath: 'video.mp4',
  frameNumber: 150,
);
```

---

## VideoProbeService

Get metadata about a video file.

### Probe a Video

```dart
final info = await VideoProbeService.probe('assets/video.mp4');

print('Duration: ${info.duration}');
print('Resolution: ${info.width}x${info.height}');
print('FPS: ${info.fps}');
print('Codec: ${info.codec}');
print('Bitrate: ${info.bitrate}');
```

### VideoInfo Properties

| Property | Type | Description |
|----------|------|-------------|
| `duration` | `Duration` | Video length |
| `width` | `int` | Video width in pixels |
| `height` | `int` | Video height in pixels |
| `fps` | `double` | Frames per second |
| `codec` | `String` | Video codec (h264, etc.) |
| `bitrate` | `int` | Bitrate in bits/sec |
| `frameCount` | `int` | Total frame count |
| `hasAudio` | `bool` | Whether video has audio |
| `audioCodec` | `String?` | Audio codec if present |

### Calculate Frame Numbers

```dart
final info = await VideoProbeService.probe('video.mp4');

// Frame at specific time
final frameAt5Sec = (5.0 * info.fps).round();

// Time at specific frame
final timeAtFrame100 = Duration(
  milliseconds: (100 / info.fps * 1000).round(),
);

// Total frames
final totalFrames = info.frameCount;
```

---

## FrameExtractionService

Extract individual frames from videos.

### Extract Single Frame

```dart
// By timestamp
final frame = await FrameExtractionService.extractFrame(
  videoPath: 'video.mp4',
  timestamp: Duration(seconds: 5),
);

// Returns Uint8List of image data (PNG format)
await File('thumbnail.png').writeAsBytes(frame);
```

### Extract by Frame Number

```dart
final frame = await FrameExtractionService.extractFrameByNumber(
  videoPath: 'video.mp4',
  frameNumber: 150,
  fps: 30.0,
);
```

### Extract Multiple Frames

```dart
// Extract frames at specific timestamps
final timestamps = [
  Duration(seconds: 0),
  Duration(seconds: 5),
  Duration(seconds: 10),
  Duration(seconds: 15),
];

final frames = await FrameExtractionService.extractFrames(
  videoPath: 'video.mp4',
  timestamps: timestamps,
);

for (var i = 0; i < frames.length; i++) {
  await File('frame_$i.png').writeAsBytes(frames[i]);
}
```

### Extract Frame Range

```dart
// Extract frames 0-30 (one second at 30fps)
final frames = await FrameExtractionService.extractFrameRange(
  videoPath: 'video.mp4',
  startFrame: 0,
  endFrame: 30,
  fps: 30.0,
);
```

### Resize During Extraction

```dart
// Extract at lower resolution
final thumbnail = await FrameExtractionService.extractFrame(
  videoPath: 'video.mp4',
  timestamp: Duration(seconds: 5),
  width: 320,   // Scale to 320px wide
  height: 180,  // Scale to 180px tall
);
```

---

## VideoFrameCache

Cache extracted frames for efficient reuse.

### Using the Cache

```dart
final cache = VideoFrameCache();

// Get frame (extracts if not cached)
final frame = await cache.getFrame(
  videoPath: 'video.mp4',
  frameNumber: 100,
  fps: 30.0,
);

// Check if cached
final isCached = cache.hasFrame('video.mp4', 100);

// Clear cache for a video
cache.clearVideo('video.mp4');

// Clear entire cache
cache.clearAll();
```

### Cache Configuration

```dart
final cache = VideoFrameCache(
  maxCacheSize: 100,        // Max frames to cache
  maxCacheSizeBytes: 100 * 1024 * 1024,  // 100MB max
  evictionPolicy: LRU,      // Least recently used
);
```

### Pre-caching Frames

```dart
// Pre-cache frames for smooth playback
await cache.precache(
  videoPath: 'video.mp4',
  frameNumbers: List.generate(300, (i) => i),
  fps: 30.0,
  onProgress: (p) => print('Caching: ${(p * 100).toStringAsFixed(0)}%'),
);
```

---

## Examples

### Generate Video Thumbnails

```dart
Future<Uint8List> generateThumbnail(String videoPath) async {
  final info = await VideoProbeService.probe(videoPath);

  // Extract frame at 10% into video
  final thumbnailTime = Duration(
    milliseconds: (info.duration.inMilliseconds * 0.1).round(),
  );

  return await FrameExtractionService.extractFrame(
    videoPath: videoPath,
    timestamp: thumbnailTime,
    width: 320,
    height: 180,
  );
}
```

### Create Video Timeline Preview

```dart
Future<List<Uint8List>> createTimelinePreview(
  String videoPath, {
  int thumbnailCount = 10,
}) async {
  final info = await VideoProbeService.probe(videoPath);
  final interval = info.duration.inMilliseconds / thumbnailCount;

  final timestamps = List.generate(
    thumbnailCount,
    (i) => Duration(milliseconds: (i * interval).round()),
  );

  return await FrameExtractionService.extractFrames(
    videoPath: videoPath,
    timestamps: timestamps,
    width: 160,
    height: 90,
  );
}
```

### Video Preview Widget

```dart
class VideoPreview extends StatefulWidget {
  final String videoPath;

  @override
  State<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<VideoPreview> {
  Uint8List? _thumbnail;
  VideoInfo? _info;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    final info = await VideoProbeService.probe(widget.videoPath);
    final thumbnail = await FrameExtractionService.extractFrame(
      videoPath: widget.videoPath,
      timestamp: Duration(seconds: 1),
      width: 320,
      height: 180,
    );

    setState(() {
      _info = info;
      _thumbnail = thumbnail;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_thumbnail == null) {
      return Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Image.memory(_thumbnail!),
        Text('${_info!.width}x${_info!.height}'),
        Text('Duration: ${_info!.duration}'),
      ],
    );
  }
}
```

### Extract Frames for EmbeddedVideo

```dart
// Used internally by EmbeddedVideo widget
Future<void> prepareEmbeddedVideo(
  String videoPath,
  int startFrame,
  int durationInFrames,
  double fps,
) async {
  final cache = VideoFrameCache();

  // Pre-extract all needed frames
  final frameNumbers = List.generate(
    durationInFrames,
    (i) => startFrame + i,
  );

  await cache.precache(
    videoPath: videoPath,
    frameNumbers: frameNumbers,
    fps: fps,
  );
}
```

---

## Performance Considerations

### Extraction Speed

| Factor | Impact |
|--------|--------|
| Video codec | H.264 fastest, H.265 slower |
| Resolution | Higher = slower |
| Seek distance | Keyframe-aligned = faster |
| SSD vs HDD | SSD significantly faster |

### Memory Usage

```dart
// Estimate memory for caching
// 1080p PNG frame ≈ 500KB-2MB
// 4K PNG frame ≈ 2MB-8MB

// For 300 frames at 1080p:
// ~150MB - 600MB memory
```

### Optimization Tips

1. **Extract at lower resolution** if full quality isn't needed:
   ```dart
   extractFrame(videoPath: path, width: 480, height: 270)
   ```

2. **Batch extractions** rather than one-by-one:
   ```dart
   extractFrames(timestamps: [...])  // Better
   // vs
   for (ts in timestamps) extractFrame(ts)  // Slower
   ```

3. **Use keyframe-aligned timestamps** when possible:
   ```dart
   // Videos typically have keyframes every 1-2 seconds
   // Extracting at keyframes is faster
   ```

4. **Clear cache** when done:
   ```dart
   cache.clearAll();
   ```

---

## Related

- [Videos](../embedding/videos.md) - Embedding videos
- [EmbeddedVideo](../widgets/media/embedded-video.md) - Video widget
- [Custom Render Pipeline](custom-render-pipeline.md)
- [Performance Tips](performance-tips.md)
