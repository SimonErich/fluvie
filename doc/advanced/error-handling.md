# Error Handling in Fluvie

Comprehensive guide to handling errors during video composition and rendering.

## Exception Hierarchy

Fluvie provides a structured exception hierarchy for better error handling and debugging:

```dart
FluvieException (base)
├── FFmpegNotFoundException
├── FFmpegExecutionException
├── RenderException
├── FrameCaptureException
├── InvalidConfigurationException
├── AudioProcessingException
├── FileNotFoundException
├── FileIOException
├── VideoProbeException
├── TimelineException
└── UnsupportedPlatformException
```

All Fluvie exceptions extend `FluvieException`, allowing you to catch all library errors with a single handler if needed.

## Common Error Scenarios

### 1. FFmpeg Not Found

**Exception**: `FFmpegNotFoundException`

**When it happens**: FFmpeg executable is not installed or not in PATH.

**Example**:
```dart
import 'package:fluvie/fluvie.dart';

try {
  await renderService.execute(...);
} on FFmpegNotFoundException catch (e) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('FFmpeg Not Found'),
      content: Text('Please install FFmpeg to use video rendering.\n\n${e.message}'),
      actions: [
        TextButton(
          onPressed: () => launchUrl('https://ffmpeg.org/download.html'),
          child: Text('Download FFmpeg'),
        ),
      ],
    ),
  );
}
```

**Prevention**:
```dart
// Check FFmpeg availability before rendering
final diagnostics = await FFmpegChecker.check();
if (!diagnostics.isAvailable) {
  print(diagnostics.errorMessage);
  print(diagnostics.installationInstructions);
  return;
}
```

### 2. FFmpeg Execution Failures

**Exception**: `FFmpegExecutionException`

**When it happens**: FFmpeg command fails during video encoding.

**Example**:
```dart
try {
  final outputPath = await renderService.execute(...);
} on FFmpegExecutionException catch (e) {
  FluvieLogger.error('FFmpeg failed', module: 'render');
  FluvieLogger.error('Exit code: ${e.exitCode}', module: 'render');
  FluvieLogger.error('Command: ${e.command}', module: 'render');
  FluvieLogger.error('Stderr: ${e.stderr}', module: 'render');

  // Handle specific exit codes
  if (e.exitCode == 1) {
    // Generic error - check stderr for details
  } else if (e.exitCode == 255) {
    // Codec or format error
    showError('Unsupported video format or codec');
  }
}
```

**Common causes**:
- Unsupported video codecs
- Corrupted input files
- Insufficient disk space
- Invalid FFmpeg arguments

### 3. Frame Capture Failures

**Exception**: `FrameCaptureException`

**When it happens**: Widget rendering or frame capture fails.

**Example**:
```dart
try {
  final image = await frameSequencer.captureFrame(pixelRatio: 3.0);
} on FrameCaptureException catch (e) {
  print('Frame capture failed: ${e.message}');
  print('Boundary key: ${e.boundaryKey}');
  if (e.frameNumber != null) {
    print('Failed at frame: ${e.frameNumber}');
  }

  // Retry with lower pixel ratio
  try {
    final image = await frameSequencer.captureFrame(pixelRatio: 1.0);
  } catch (retryError) {
    // Still failed - report error
    reportError(retryError);
  }
}
```

**Common causes**:
- Missing RepaintBoundary widget
- Widget tree not properly built
- Memory exhaustion
- Platform rendering issues

**Prevention**:
```dart
// Ensure RepaintBoundary is properly set up
final boundaryKey = GlobalKey();

RepaintBoundary(
  key: boundaryKey,
  child: VideoComposition(
    fps: 30,
    durationInFrames: 90,
    child: MyContent(),
  ),
)
```

### 4. Rendering Failures

**Exception**: `RenderException`

**When it happens**: General rendering pipeline failures.

**Example**:
```dart
try {
  final outputPath = await renderService.execute(
    config: config,
    onFrameUpdate: (frame) {
      print('Rendering frame $frame');
    },
  );
} on RenderException catch (e) {
  if (e.frameNumber != null) {
    print('Rendering failed at frame ${e.frameNumber}');
    // Maybe skip this frame or stop rendering
  }

  // Log error for debugging
  FluvieLogger.error('Render failed: ${e.message}', module: 'render');
  if (e.cause != null) {
    FluvieLogger.error('Caused by: ${e.cause}', module: 'render');
  }
}
```

### 5. Configuration Errors

**Exception**: `InvalidConfigurationException`

**When it happens**: Invalid parameters passed to Fluvie APIs.

**Example**:
```dart
try {
  final composition = VideoComposition(
    fps: -1,  // Invalid!
    durationInFrames: 90,
    child: MyContent(),
  );
} on InvalidConfigurationException catch (e) {
  print('Invalid configuration: ${e.message}');
  print('Field: ${e.fieldName}');
  print('Value: ${e.invalidValue}');

  // Show validation error to user
  showSnackBar('${e.fieldName}: ${e.message}');
}
```

**Validation before rendering**:
```dart
void validateConfig(RenderConfig config) {
  if (config.timeline.fps <= 0) {
    throw InvalidConfigurationException(
      'FPS must be greater than 0',
      fieldName: 'fps',
      invalidValue: config.timeline.fps,
    );
  }

  if (config.timeline.durationInFrames <= 0) {
    throw InvalidConfigurationException(
      'Duration must be greater than 0 frames',
      fieldName: 'durationInFrames',
      invalidValue: config.timeline.durationInFrames,
    );
  }
}
```

### 6. Audio Processing Failures

**Exception**: `AudioProcessingException`

**When it happens**: Audio file loading, BPM detection, or processing fails.

**Example**:
```dart
try {
  final metadata = await videoProbeService.probe('song.mp3');
} on AudioProcessingException catch (e) {
  print('Audio processing failed: ${e.message}');
  print('Operation: ${e.operation}');
  print('File: ${e.audioFilePath}');

  // Fall back to no audio
  renderWithoutAudio();
}
```

**Handling missing audio gracefully**:
```dart
AudioTrack? loadAudio(String path) {
  try {
    return AudioTrack(
      source: AudioSource.file(path),
      volume: 1.0,
    );
  } on FileNotFoundException {
    FluvieLogger.warning('Audio file not found, rendering without audio');
    return null;
  }
}
```

### 7. File Not Found Errors

**Exception**: `FileNotFoundException`

**When it happens**: Required files (video, audio, assets) don't exist.

**Example**:
```dart
try {
  final video = VideoSequence(
    source: VideoSource.file('/path/to/video.mp4'),
    startFrame: 0,
    durationInFrames: 90,
  );
} on FileNotFoundException catch (e) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('File Not Found'),
      content: Text('Could not find: ${e.filePath}'),
      actions: [
        TextButton(
          onPressed: () => pickFile(),
          child: Text('Choose File'),
        ),
      ],
    ),
  );
}
```

**Validation before use**:
```dart
import 'dart:io';

Future<void> validateFile(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    throw FileNotFoundException(path);
  }

  // Check file is readable
  try {
    await file.length();
  } catch (e) {
    throw FileIOException(
      'File exists but cannot be read',
      filePath: path,
      operation: 'read',
      cause: e,
    );
  }
}
```

### 8. Timeline Configuration Errors

**Exception**: `TimelineException`

**When it happens**: Invalid frame ranges, overlapping sequences, etc.

**Example**:
```dart
try {
  final sequence = Sequence(
    startFrame: 100,
    endFrame: 50,  // Invalid: end before start!
    child: MyWidget(),
  );
} on TimelineException catch (e) {
  print('Timeline error: ${e.message}');
  print('Start frame: ${e.startFrame}');
  print('End frame: ${e.endFrame}');

  // Fix the configuration
  final fixed = Sequence(
    startFrame: min(e.startFrame!, e.endFrame!),
    endFrame: max(e.startFrame!, e.endFrame!),
    child: MyWidget(),
  );
}
```

## Best Practices

### 1. Always Use Specific Exception Types

**Bad**:
```dart
try {
  await renderService.execute(...);
} catch (e) {
  print('Something went wrong: $e');
}
```

**Good**:
```dart
try {
  await renderService.execute(...);
} on FFmpegNotFoundException catch (e) {
  handleMissingFFmpeg(e);
} on FFmpegExecutionException catch (e) {
  handleFFmpegFailure(e);
} on FrameCaptureException catch (e) {
  handleFrameCaptureFailure(e);
} on FluvieException catch (e) {
  handleGenericFluvieError(e);
} catch (e, stack) {
  handleUnexpectedError(e, stack);
}
```

### 2. Provide User-Friendly Error Messages

**Bad**:
```dart
} on FluvieException catch (e) {
  showDialog(content: Text(e.toString()));  // Too technical
}
```

**Good**:
```dart
} on FFmpegNotFoundException catch (e) {
  showDialog(
    content: Text('Video rendering requires FFmpeg. Would you like to install it?'),
    actions: [InstallButton()],
  );
} on FrameCaptureException catch (e) {
  showDialog(
    content: Text('Failed to capture video frame. Please try again or reduce quality.'),
  );
}
```

### 3. Log Errors for Debugging

```dart
import 'package:fluvie/fluvie.dart';

void handleError(FluvieException e, StackTrace? stack) {
  // Log to Fluvie logger
  FluvieLogger.error(e.message, module: 'app');

  // Log cause if available
  if (e.cause != null) {
    FluvieLogger.error('Caused by: ${e.cause}', module: 'app');
  }

  // Log stack trace for debugging
  if (stack != null) {
    FluvieLogger.error('Stack trace:\n$stack', module: 'app');
  }

  // Send to crash reporting service (e.g., Sentry, Firebase Crashlytics)
  crashReporting.recordError(e, stack);
}
```

### 4. Retry Logic for Transient Failures

```dart
Future<String> renderWithRetry(
  RenderConfig config, {
  int maxAttempts = 3,
}) async {
  for (int attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await renderService.execute(config: config, ...);
    } on FrameCaptureException catch (e) {
      if (attempt == maxAttempts) rethrow;

      FluvieLogger.warning(
        'Frame capture failed (attempt $attempt/$maxAttempts), retrying...',
        module: 'render',
      );

      await Future.delayed(Duration(seconds: 1));
    }
  }

  throw RenderException('Failed after $maxAttempts attempts');
}
```

### 5. Graceful Degradation

```dart
Future<String> renderVideo(VideoComposition composition) async {
  // Try with high quality first
  try {
    return await renderService.execute(
      config: RenderConfig(
        width: 1920,
        height: 1080,
        ...
      ),
    );
  } on FrameCaptureException {
    // Fall back to lower quality
    FluvieLogger.warning('Falling back to 720p rendering');
    return await renderService.execute(
      config: RenderConfig(
        width: 1280,
        height: 720,
        ...
      ),
    );
  }
}
```

### 6. Validate Early

```dart
class SafeVideoComposition extends StatelessWidget {
  final int fps;
  final int durationInFrames;
  final Widget child;

  const SafeVideoComposition({
    required this.fps,
    required this.durationInFrames,
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Validate parameters early
    if (fps <= 0) {
      throw InvalidConfigurationException(
        'FPS must be greater than 0',
        fieldName: 'fps',
        invalidValue: fps,
      );
    }

    if (durationInFrames <= 0) {
      throw InvalidConfigurationException(
        'Duration must be greater than 0',
        fieldName: 'durationInFrames',
        invalidValue: durationInFrames,
      );
    }

    return VideoComposition(
      fps: fps,
      durationInFrames: durationInFrames,
      child: child,
    );
  }
}
```

## Error Recovery Strategies

### Strategy 1: Restart Rendering

```dart
Future<String?> renderWithRestart(RenderConfig config) async {
  try {
    return await renderService.execute(config: config, ...);
  } on RenderException catch (e) {
    if (e.frameNumber != null && e.frameNumber! > 10) {
      // Rendering failed mid-way - restart from scratch
      FluvieLogger.warning('Restarting render from frame 0');

      // Clear any partial output
      await cleanupPartialRender();

      // Try again
      return await renderService.execute(config: config, ...);
    }
    rethrow;
  }
}
```

### Strategy 2: Skip Problematic Frames

```dart
Future<String> renderWithSkip(RenderConfig config) async {
  final failedFrames = <int>[];

  try {
    return await renderService.execute(
      config: config,
      onFrameUpdate: (frame) {
        // Track progress
      },
    );
  } on FrameCaptureException catch (e) {
    if (e.frameNumber != null) {
      failedFrames.add(e.frameNumber!);

      if (failedFrames.length > 10) {
        throw RenderException(
          'Too many failed frames: $failedFrames',
        );
      }

      // Continue with next frame
      return renderNextFrame();
    }
    rethrow;
  }
}
```

### Strategy 3: Reduce Quality

```dart
Future<String> renderWithQualityReduction(RenderConfig config) async {
  try {
    return await renderService.execute(config: config, ...);
  } on FrameCaptureException {
    FluvieLogger.warning('Reducing pixel ratio due to capture failure');

    // Modify config to use lower pixel ratio
    final lowerQualityConfig = config.copyWith(
      pixelRatio: config.pixelRatio / 2,
    );

    return await renderService.execute(config: lowerQualityConfig, ...);
  }
}
```

## Testing Error Handling

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

void main() {
  group('Error Handling', () {
    test('throws InvalidConfigurationException for negative FPS', () {
      expect(
        () => VideoComposition(
          fps: -1,
          durationInFrames: 90,
          child: Container(),
        ),
        throwsA(isA<InvalidConfigurationException>()),
      );
    });

    test('throws FileNotFoundException for missing file', () async {
      expect(
        () async => VideoSequence(
          source: VideoSource.file('/nonexistent/video.mp4'),
          startFrame: 0,
          durationInFrames: 90,
        ),
        throwsA(isA<FileNotFoundException>()),
      );
    });

    test('provides detailed error information', () async {
      try {
        throw FFmpegExecutionException(
          'Codec not supported',
          exitCode: 1,
          stderr: 'Unknown codec: abc123',
          command: 'ffmpeg -i input.mp4 ...',
        );
      } on FFmpegExecutionException catch (e) {
        expect(e.message, contains('Codec not supported'));
        expect(e.exitCode, equals(1));
        expect(e.stderr, contains('Unknown codec'));
        expect(e.command, contains('ffmpeg'));
      }
    });
  });
}
```

## Debugging Tips

### 1. Enable Verbose Logging

```dart
// Enable Fluvie logging
FluvieLogger.setLevel(LogLevel.debug);

// This will print detailed error information
try {
  await renderService.execute(...);
} on FluvieException catch (e, stack) {
  FluvieLogger.error(e.toString(), module: 'app');
  FluvieLogger.error('Stack: $stack', module: 'app');
}
```

### 2. Inspect FFmpeg Commands

```dart
} on FFmpegExecutionException catch (e) {
  // Print the exact FFmpeg command that failed
  print('Failed FFmpeg command:');
  print(e.command);

  // Try running it manually to see the full error
  print('\nRun this command manually to debug:');
  print(e.command);
}
```

### 3. Check System Resources

```dart
import 'dart:io';

void checkResources() {
  // Check disk space
  final tempDir = Directory.systemTemp;
  final stat = tempDir.statSync();
  print('Temp dir: ${tempDir.path}');

  // Check available memory (platform-specific)
  // On Linux: cat /proc/meminfo
  // On macOS: vm_stat
}
```

## Related Documentation

- [Custom Exception Types](../../lib/src/exceptions/fluvie_exceptions.dart) - Source code
- [Security Best Practices](../security/best-practices.md) - Input validation
- [Troubleshooting](../troubleshooting.md) - Common issues and solutions

---

**Last Updated**: 2025-12-29

Remember: Good error handling makes the difference between a frustrating user experience and a robust, reliable application!
