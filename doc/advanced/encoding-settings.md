# Encoding Settings

> **Control video quality, format, and compression**

Fluvie provides extensive control over the final video encoding through the `EncodingConfig` class.

## Table of Contents

- [Overview](#overview)
- [RenderQuality Presets](#renderquality-presets)
- [Custom Settings](#custom-settings)
- [Output Formats](#output-formats)
- [Debug Options](#debug-options)
- [Examples](#examples)

---

## Overview

Encoding settings control how FFmpeg encodes your final video:

```dart
final settings = EncodingConfig(
  quality: RenderQuality.high,
  outputFormat: OutputFormat.mp4,
  audioCodec: AudioCodec.aac,
);

await RenderService.execute(
  composition: video,
  outputPath: 'output.mp4',
  settings: settings,
  tester: tester,
);
```

---

## RenderQuality Presets

### Available Presets

| Preset | CRF | Preset | Use Case |
|--------|-----|--------|----------|
| `preview` | 28 | `ultrafast` | Quick previews, testing |
| `standard` | 23 | `medium` | General use, good balance |
| `high` | 18 | `slow` | Final output, best quality |
| `lossless` | 0 | `veryslow` | Archival, no quality loss |

### Using Presets

```dart
// Quick preview
EncodingConfig(quality: RenderQuality.preview)

// Standard output
EncodingConfig(quality: RenderQuality.standard)

// High quality final
EncodingConfig(quality: RenderQuality.high)

// Lossless (very large files)
EncodingConfig(quality: RenderQuality.lossless)
```

### Preset Details

#### Preview Quality
- **CRF**: 28 (lower quality)
- **Preset**: ultrafast
- **Use**: Testing, iteration
- **File size**: Small
- **Speed**: Very fast

#### Standard Quality
- **CRF**: 23 (good quality)
- **Preset**: medium
- **Use**: General distribution
- **File size**: Moderate
- **Speed**: Moderate

#### High Quality
- **CRF**: 18 (excellent quality)
- **Preset**: slow
- **Use**: Final exports
- **File size**: Larger
- **Speed**: Slow

#### Lossless
- **CRF**: 0 (perfect quality)
- **Preset**: veryslow
- **Use**: Archival, further editing
- **File size**: Very large
- **Speed**: Very slow

---

## Custom Settings

### CRF (Constant Rate Factor)

CRF controls quality. Lower = better quality, larger files.

```dart
EncodingConfig(
  crf: 20,  // Custom CRF (0-51 for H.264)
)
```

| CRF Range | Quality | File Size |
|-----------|---------|-----------|
| 0-17 | Visually lossless | Large |
| 18-23 | High quality | Moderate |
| 24-28 | Good quality | Smaller |
| 29+ | Lower quality | Small |

### FFmpeg Preset

Controls encoding speed vs compression efficiency:

```dart
EncodingConfig(
  preset: 'slow',  // Better compression, slower
)
```

| Preset | Speed | Compression |
|--------|-------|-------------|
| `ultrafast` | Fastest | Lowest |
| `superfast` | Very fast | Low |
| `veryfast` | Fast | Below average |
| `faster` | Fast | Average |
| `fast` | Medium-fast | Above average |
| `medium` | Medium | Good |
| `slow` | Slow | Better |
| `slower` | Very slow | Very good |
| `veryslow` | Slowest | Best |

### Video Codec

```dart
EncodingConfig(
  videoCodec: VideoCodec.h264,  // Most compatible
  // or
  videoCodec: VideoCodec.h265,  // Better compression
  // or
  videoCodec: VideoCodec.vp9,   // Open format
)
```

### Audio Codec

```dart
EncodingConfig(
  audioCodec: AudioCodec.aac,   // Most compatible
  // or
  audioCodec: AudioCodec.mp3,   // Universal
  // or
  audioCodec: AudioCodec.opus,  // Best quality per bit
)
```

### Audio Bitrate

```dart
EncodingConfig(
  audioBitrate: '192k',  // Higher quality audio
)
```

| Bitrate | Quality | Use Case |
|---------|---------|----------|
| `96k` | Acceptable | Speech |
| `128k` | Good | General |
| `192k` | High | Music |
| `320k` | Excellent | High-fidelity |

---

## Output Formats

### MP4 (Recommended)

Most compatible format:

```dart
EncodingConfig(
  outputFormat: OutputFormat.mp4,
  videoCodec: VideoCodec.h264,
  audioCodec: AudioCodec.aac,
)
```

### WebM

Open format, good for web:

```dart
EncodingConfig(
  outputFormat: OutputFormat.webm,
  videoCodec: VideoCodec.vp9,
  audioCodec: AudioCodec.opus,
)
```

### MOV

Apple ecosystem:

```dart
EncodingConfig(
  outputFormat: OutputFormat.mov,
  videoCodec: VideoCodec.h264,
  audioCodec: AudioCodec.aac,
)
```

### GIF

Animated images (no audio):

```dart
EncodingConfig(
  outputFormat: OutputFormat.gif,
)
```

---

## Frame Format

Control how frames are captured before encoding:

```dart
EncodingConfig(
  frameFormat: FrameFormat.png,  // Higher quality, slower
  // or
  frameFormat: FrameFormat.rawRgba,  // Faster, more memory
)
```

| Format | Quality | Speed | Memory |
|--------|---------|-------|--------|
| PNG | Lossless | Slower | Lower |
| Raw RGBA | Lossless | Faster | Higher |

---

## Debug Options

### Save Individual Frames

```dart
EncodingConfig(
  debugOutputFrames: true,
  debugFramesPath: '/tmp/frames/',
)
```

This saves each frame as a PNG file, useful for:
- Debugging visual issues
- Creating frame-by-frame animations
- Inspecting specific frames

### Verbose Logging

```dart
EncodingConfig(
  verbose: true,  // Print FFmpeg output
)
```

---

## Examples

### Social Media Export

```dart
// Instagram/TikTok optimized
EncodingConfig(
  quality: RenderQuality.high,
  outputFormat: OutputFormat.mp4,
  videoCodec: VideoCodec.h264,
  audioCodec: AudioCodec.aac,
  audioBitrate: '192k',
)
```

### Web Optimized

```dart
// Smaller file for web streaming
EncodingConfig(
  crf: 25,
  preset: 'fast',
  outputFormat: OutputFormat.mp4,
  audioBitrate: '128k',
)
```

### Archival Quality

```dart
// Maximum quality preservation
EncodingConfig(
  quality: RenderQuality.lossless,
  outputFormat: OutputFormat.mov,
  frameFormat: FrameFormat.png,
)
```

### Fast Preview

```dart
// Quick iteration
EncodingConfig(
  quality: RenderQuality.preview,
  outputFormat: OutputFormat.mp4,
)
```

### Custom Fine-Tuned

```dart
EncodingConfig(
  crf: 20,
  preset: 'slow',
  videoCodec: VideoCodec.h264,
  audioCodec: AudioCodec.aac,
  audioBitrate: '256k',
  outputFormat: OutputFormat.mp4,
  // Extra FFmpeg arguments
  extraArgs: ['-movflags', '+faststart'],
)
```

---

## File Size Estimation

Rough estimates for 1080p video:

| Quality | Bitrate | 1 min | 5 min |
|---------|---------|-------|-------|
| Preview (CRF 28) | ~2 Mbps | ~15 MB | ~75 MB |
| Standard (CRF 23) | ~5 Mbps | ~38 MB | ~188 MB |
| High (CRF 18) | ~10 Mbps | ~75 MB | ~375 MB |
| Lossless | ~50+ Mbps | ~400+ MB | ~2+ GB |

---

## Related

- [Custom Render Pipeline](custom-render-pipeline.md)
- [Performance Tips](performance-tips.md)
- [ONLY_SERVER_MODE](../ONLY_SERVER_MODE.md)
