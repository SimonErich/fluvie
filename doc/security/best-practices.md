# Security Best Practices

Guidelines for using Fluvie securely in production applications.

## Overview

Fluvie processes user-provided content and executes FFmpeg commands. Follow these best practices to prevent security vulnerabilities.

## Input Validation

### ✅ DO: Validate File Paths

Always validate file paths before using them:

```dart
import 'dart:io';
import 'package:path/path.dart' as path;

String sanitizeFilePath(String userInput) {
  // Remove path traversal attempts
  final normalized = path.normalize(userInput);

  // Ensure path doesn't escape allowed directory
  if (normalized.contains('..')) {
    throw ArgumentError('Invalid file path: path traversal detected');
  }

  // Check file exists
  if (!File(normalized).existsSync()) {
    throw FileNotFoundException(normalized);
  }

  return normalized;
}

// Usage:
try {
  final safePath = sanitizeFilePath(userProvidedPath);
  final video = VideoSource.file(safePath);
} catch (e) {
  // Handle invalid path
}
```

### ❌ DON'T: Use Raw User Input

```dart
// DANGEROUS: Direct user input to video source
final videoPath = request.params['video'];  // Unsafe!
final video = VideoSource.file(videoPath);  // Could access any file!
```

### ✅ DO: Restrict to Allowed Directories

```dart
Future<String> validateVideoPath(String userPath) async {
  final allowedDir = await getApplicationDocumentsDirectory();
  final fullPath = path.join(allowedDir.path, 'videos', userPath);
  final normalized = path.normalize(fullPath);

  // Ensure path is within allowed directory
  if (!normalized.startsWith(allowedDir.path)) {
    throw SecurityException('Path outside allowed directory');
  }

  return normalized;
}
```

## FFmpeg Command Injection

Fluvie sanitizes FFmpeg arguments, but additional precautions are recommended.

### ✅ DO: Use Fluvie's Type-Safe APIs

```dart
// Safe: Type-safe API
VideoSequence(
  source: VideoSource.asset('video.mp4'),
  startTime: Duration(seconds: 5),
  duration: Duration(seconds: 10),
)

AudioTrack(
  source: AudioSource.file('/path/to/audio.mp3'),
  volume: 0.8,
)
```

### ❌ DON'T: Build Raw FFmpeg Commands

```dart
// DANGEROUS: Manual FFmpeg command building
final userFile = getUserInput();  // Unsafe!
final cmd = 'ffmpeg -i $userFile output.mp4';  // Command injection risk!
Process.run('ffmpeg', ['-i', userFile, 'output.mp4']);  // Still risky!
```

### ✅ DO: Validate Media File Types

```dart
bool isAllowedMediaType(String filePath) {
  final allowedExtensions = {'.mp4', '.mov', '.avi', '.mp3', '.wav', '.m4a'};
  final extension = path.extension(filePath).toLowerCase();
  return allowedExtensions.contains(extension);
}

// Usage:
if (!isAllowedMediaType(userPath)) {
  throw ArgumentError('Unsupported file type');
}
```

## File System Access

### ✅ DO: Restrict Output Directories

```dart
import 'package:path_provider/path_provider.dart';

Future<void> configureSecureOutput() async {
  // Use app-specific directory
  final outputDir = await getTemporaryDirectory();

  FluvieConfig.configure(
    outputDirectory: outputDir.path,
  );
}
```

### ❌ DON'T: Allow Arbitrary Paths

```dart
// DANGEROUS: User controls output path
final userOutputPath = request.params['output'];  // Unsafe!
FluvieConfig.configure(
  outputDirectory: userOutputPath,  // Path traversal risk!
);
```

### ✅ DO: Generate Safe File Names

```dart
import 'package:uuid/uuid.dart';

String generateSafeFileName() {
  final uuid = Uuid().v4();
  return 'video_$uuid.mp4';  // Safe, unique filename
}

// Usage:
final outputPath = path.join(
  secureOutputDirectory,
  generateSafeFileName(),
);
```

## Web Security

When running Fluvie on web platforms:

### Required Server Headers

Configure your web server to send:

```nginx
# nginx configuration
add_header Cross-Origin-Embedder-Policy "require-corp";
add_header Cross-Origin-Opener-Policy "same-origin";
```

```apache
# Apache configuration
Header set Cross-Origin-Embedder-Policy "require-corp"
Header set Cross-Origin-Opener-Policy "same-origin"
```

### Content Security Policy

Add CSP headers to prevent XSS:

```html
<meta http-equiv="Content-Security-Policy"
      content="default-src 'self';
               script-src 'self' 'unsafe-inline' 'unsafe-eval' https://unpkg.com;
               worker-src 'self' blob:;">
```

### Validate SharedArrayBuffer

```dart
import 'dart:html' as html;

bool isSharedArrayBufferAvailable() {
  try {
    // Check if SharedArrayBuffer is available
    return html.window.navigator.userAgent.isNotEmpty &&
           js.context.hasProperty('SharedArrayBuffer');
  } catch (e) {
    return false;
  }
}

// Usage:
if (!isSharedArrayBufferAvailable()) {
  throw UnsupportedError(
    'SharedArrayBuffer not available. Check server headers.',
  );
}
```

## Resource Limits

### ✅ DO: Set Composition Size Limits

```dart
const maxWidth = 3840;   // 4K max
const maxHeight = 2160;
const maxDuration = 600; // 10 minutes max

void validateComposition(VideoComposition composition) {
  if (composition.width > maxWidth || composition.height > maxHeight) {
    throw ArgumentError('Composition size exceeds limits');
  }

  final durationInSeconds = composition.durationInFrames / composition.fps;
  if (durationInSeconds > maxDuration) {
    throw ArgumentError('Composition duration exceeds limit');
  }
}
```

### ✅ DO: Limit File Sizes

```dart
const maxFileSize = 100 * 1024 * 1024; // 100 MB

Future<void> validateFileSize(String filePath) async {
  final file = File(filePath);
  final size = await file.length();

  if (size > maxFileSize) {
    throw ArgumentError('File size exceeds ${maxFileSize ~/ 1024 ~/ 1024} MB limit');
  }
}
```

### ✅ DO: Implement Timeouts

```dart
Future<String> renderWithTimeout(RenderConfig config) async {
  return await Future.any([
    renderService.execute(config: config, ...),
    Future.delayed(
      Duration(minutes: 30),
      () => throw TimeoutException('Render exceeded 30 minute timeout'),
    ),
  ]);
}
```

## Temporary File Management

### ✅ DO: Clean Up Temporary Files

```dart
Future<void> renderAndCleanup(RenderConfig config) async {
  final tempDir = await Directory.systemTemp.createTemp('fluvie_');

  try {
    FluvieConfig.configure(
      outputDirectory: tempDir.path,
      cleanupTempFiles: true,  // Auto cleanup
    );

    await renderService.execute(config: config, ...);
  } finally {
    // Ensure cleanup even if render fails
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  }
}
```

### ❌ DON'T: Leave Sensitive Data

```dart
// Bad: Sensitive content left in temp directory
await renderService.execute(...);
// Temp files with user content remain!
```

## API Rate Limiting

For server-side video generation:

### ✅ DO: Implement Rate Limits

```dart
import 'package:shelf_rate_limiter/shelf_rate_limiter.dart';

final handler = Pipeline()
    .addMiddleware(
      rateLimiter(
        requestsPerMinute: 10,  // Max 10 renders per minute
      ),
    )
    .addHandler(renderVideoHandler);
```

### ✅ DO: Queue Long-Running Tasks

```dart
import 'package:queue/queue.dart';

final renderQueue = Queue(
  parallel: 2,  // Max 2 concurrent renders
  timeout: Duration(minutes: 30),
);

Future<String> queuedRender(RenderConfig config) {
  return renderQueue.add(() => renderService.execute(config: config, ...));
}
```

## Error Handling

### ✅ DO: Sanitize Error Messages

```dart
// Don't expose internal paths in errors
try {
  await renderService.execute(...);
} catch (e) {
  // Bad: Exposes internal path
  // throw Exception('Failed to render: $e');

  // Good: Generic error message
  FluvieLogger.error('Render failed', module: 'security');
  throw RenderException('Video generation failed. Please try again.');
}
```

### ✅ DO: Log Security Events

```dart
void logSecurityEvent(String event, {Map<String, dynamic>? details}) {
  FluvieLogger.warning(
    'Security event: $event',
    module: 'security',
  );

  // Send to security monitoring system
  securityMonitor.log(event, details);
}

// Usage:
if (!isValidPath(userPath)) {
  logSecurityEvent('Invalid path attempt', {
    'path': userPath,
    'user': currentUser.id,
  });
  throw SecurityException('Invalid path');
}
```

## Mobile Considerations

### Android

```dart
// Request only necessary permissions
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
                 android:maxSdkVersion="28" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />

// Use scoped storage (Android 10+)
final outputDir = await getExternalStorageDirectory();
```

### iOS

```dart
// Declare usage in Info.plist
<key>NSPhotoLibraryUsageDescription</key>
<string>Save rendered videos to your photo library</string>

// Use app sandbox
final outputDir = await getApplicationDocumentsDirectory();
```

## Checklist

Before deploying Fluvie in production:

- [ ] Validate all file paths
- [ ] Restrict output directories
- [ ] Set resource limits (size, duration, memory)
- [ ] Implement timeouts
- [ ] Configure web security headers (if web)
- [ ] Clean up temporary files
- [ ] Sanitize error messages
- [ ] Log security events
- [ ] Implement rate limiting (if server-side)
- [ ] Test with malicious inputs
- [ ] Review FFmpeg command generation
- [ ] Set up monitoring and alerts

## Related Documentation

- [Web Setup](../platform_setup/web.md) - Web-specific security
- [Mobile Setup](../platform_setup/mobile.md) - Mobile permissions
- [Custom Render Pipeline](../advanced/custom-render-pipeline.md) - Advanced security

## Reporting Security Issues

Found a security vulnerability? Please report it responsibly:

- **Email**: [security contact - see SECURITY.md](../../SECURITY.md)
- **Do not** open public GitHub issues for security vulnerabilities
- We aim to respond within 48 hours

---

**Last Updated**: 2025-12-29

Keep your users safe by following these practices!
