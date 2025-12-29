# Mobile Setup (Android & iOS)

> **Configure FFmpegKit for mobile video encoding**

Mobile platforms don't have system FFmpeg available, so you need to use a custom provider. We recommend [FFmpegKit](https://github.com/arthenica/ffmpeg-kit).

## Table of Contents

- [Using FFmpegKit](#using-ffmpegkit)
- [Android Configuration](#android-configuration)
- [iOS Configuration](#ios-configuration)
- [FFmpegKit Variants](#ffmpegkit-variants)
- [Troubleshooting](#troubleshooting)

---

## Using FFmpegKit

### Add Dependency

```yaml
dependencies:
  ffmpeg_kit_flutter: ^6.0.3
```

### Create a Custom Provider

Create a file `lib/ffmpeg_kit_provider.dart`:

```dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:fluvie/fluvie.dart';
import 'package:path_provider/path_provider.dart';

class FFmpegKitProvider implements FFmpegProvider {
  @override
  String get name => 'FFmpegKit';

  @override
  Future<bool> isAvailable() async {
    // FFmpegKit is always available when the package is included
    return true;
  }

  @override
  Future<FFmpegSession> startSession(FFmpegSessionConfig config) async {
    return _FFmpegKitSession(config);
  }

  @override
  Future<void> dispose() async {}
}

class _FFmpegKitSession implements FFmpegSession {
  final FFmpegSessionConfig config;
  final _progressController = StreamController<double>.broadcast();
  final _completedCompleter = Completer<String>();

  late final String _inputPath;
  late final String _outputPath;
  late final IOSink _inputSink;
  int _framesWritten = 0;
  bool _finalized = false;

  _FFmpegKitSession(this.config) {
    _initialize();
  }

  Future<void> _initialize() async {
    final tempDir = await getTemporaryDirectory();
    _inputPath = '${tempDir.path}/fluvie_input_${DateTime.now().millisecondsSinceEpoch}.raw';
    _outputPath = '${tempDir.path}/${config.outputFileName}';

    // Create input file for raw frames
    final inputFile = File(_inputPath);
    _inputSink = inputFile.openWrite();
  }

  @override
  Stream<double> get progress => _progressController.stream;

  @override
  Future<String> get completed => _completedCompleter.future;

  @override
  Future<void> addFrame(Uint8List rgbaBytes) async {
    if (_finalized) {
      throw StateError('Cannot add frames after finalize() was called');
    }

    _inputSink.add(rgbaBytes);
    _framesWritten++;

    if (config.totalFrames > 0) {
      final progress = (_framesWritten / config.totalFrames).clamp(0.0, 0.99);
      _progressController.add(progress);
    }
  }

  @override
  Future<void> finalize() async {
    if (_finalized) return;
    _finalized = true;

    await _inputSink.close();

    // Build FFmpeg command
    final command = _buildCommand();

    // Execute FFmpeg
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      _progressController.add(1.0);
      _completedCompleter.complete(_outputPath);
    } else {
      final logs = await session.getAllLogsAsString();
      _completedCompleter.completeError(
        FFmpegEncodingException(
          'FFmpegKit encoding failed',
          exitCode: returnCode?.getValue() ?? -1,
          stderrOutput: logs,
        ),
      );
    }

    _progressController.close();

    // Clean up input file
    try {
      await File(_inputPath).delete();
    } catch (_) {}
  }

  String _buildCommand() {
    final args = <String>[
      '-y',
      '-f', 'rawvideo',
      '-pixel_format', 'rgba',
      '-video_size', '${config.width}x${config.height}',
      '-framerate', '${config.fps}',
      '-i', _inputPath,
    ];

    // Add audio inputs
    for (final audio in config.audioInputs) {
      args.addAll(['-i', audio.uri]);
    }

    // Add filter graph
    if (config.filterGraph != null && config.filterGraph!.isNotEmpty) {
      args.addAll(['-filter_complex', config.filterGraph!]);
      if (config.videoOutputLabel != null) {
        args.addAll(['-map', config.videoOutputLabel!]);
      }
      if (config.audioOutputLabel != null) {
        args.addAll(['-map', config.audioOutputLabel!]);
      }
    } else {
      args.addAll(['-vf', 'fps=${config.fps},format=${config.pixelFormat}']);
    }

    // Video codec
    args.addAll([
      '-c:v', config.videoCodec,
      '-preset', config.preset,
      '-crf', '${config.crf}',
      '-pix_fmt', config.pixelFormat,
    ]);

    // Audio codec
    if (config.audioInputs.isNotEmpty) {
      args.addAll(['-c:a', 'aac', '-b:a', '192k']);
    }

    args.add(_outputPath);

    return args.join(' ');
  }

  @override
  Future<void> cancel() async {
    _finalized = true;
    FFmpegKit.cancel();

    if (!_completedCompleter.isCompleted) {
      _completedCompleter.completeError(
        FFmpegEncodingException('Encoding cancelled by user'),
      );
    }
    _progressController.close();

    // Clean up files
    try {
      await File(_inputPath).delete();
      await File(_outputPath).delete();
    } catch (_) {}
  }
}
```

### Register the Provider

In your app's `main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:fluvie/fluvie.dart';
import 'ffmpeg_kit_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Register FFmpegKit provider for mobile
  FFmpegProviderRegistry.setProvider(FFmpegKitProvider());

  runApp(MyApp());
}
```

## Android Configuration

### Min SDK Version

FFmpegKit requires Android API 24+. In `android/app/build.gradle`:

```gradle
android {
    defaultConfig {
        minSdkVersion 24
    }
}
```

### ProGuard Rules

If using ProGuard/R8, add to `android/app/proguard-rules.pro`:

```proguard
-keep class com.arthenica.ffmpegkit.** { *; }
```

## iOS Configuration

### Minimum iOS Version

FFmpegKit requires iOS 12.1+. In `ios/Podfile`:

```ruby
platform :ios, '12.1'
```

### Podfile Configuration

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.1'
    end
  end
end
```

## FFmpegKit Variants

FFmpegKit comes in different variants with different codec support:

| Variant | Size | Codecs |
|---------|------|--------|
| min | ~8MB | Basic codecs |
| min-gpl | ~10MB | + x264 |
| full | ~30MB | All codecs |
| full-gpl | ~35MB | All + GPL codecs |

To use a specific variant:

```yaml
dependencies:
  ffmpeg_kit_flutter_full: ^6.0.3  # Full variant
```

## Troubleshooting

### Build Fails on Android

1. Check min SDK version is 24+
2. Clean and rebuild: `flutter clean && flutter pub get`
3. Check for conflicting native libraries

### Build Fails on iOS

1. Check iOS deployment target is 12.1+
2. Run `cd ios && pod install --repo-update`
3. Check for bitcode issues (disable if needed)

### Large App Size

FFmpegKit adds significant size. Options:

1. Use `min` variant for smaller size
2. Use app bundles (Android) or app thinning (iOS)
3. Consider on-demand download of FFmpeg

### Performance on Older Devices

Mobile encoding is CPU-intensive. Tips:

1. Use lower resolution (720p)
2. Use fewer frames (24fps)
3. Show progress to users
4. Consider background processing

---

## Related

- [Platform Overview](overview.md) - All platforms
- [Custom FFmpeg Provider](../extending/custom-ffmpeg-provider.md) - Provider implementation details
- [Performance Tips](../advanced/performance-tips.md) - Optimization strategies
- [Encoding Settings](../advanced/encoding-settings.md) - Quality vs. speed tradeoffs
