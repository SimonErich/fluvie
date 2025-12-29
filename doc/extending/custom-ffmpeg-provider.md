# Custom FFmpeg Provider

> **Implement platform-specific FFmpeg integrations**

Fluvie uses FFmpeg for video encoding. The FFmpeg provider abstraction allows different implementations for different platforms.

## Table of Contents

- [Overview](#overview)
- [FFmpegProvider Interface](#ffmpegprovider-interface)
- [ProcessFFmpegProvider](#processffmpegprovider)
- [Mobile FFmpegKit](#mobile-ffmpegkit)
- [Custom Implementation](#custom-implementation)
- [Testing Providers](#testing-providers)

---

## Overview

Fluvie abstracts FFmpeg access through the `FFmpegProvider` interface:

```
┌─────────────────────────────────────────────┐
│              RenderService                   │
├─────────────────────────────────────────────┤
│           FFmpegProvider (abstract)          │
├─────────────┬─────────────┬─────────────────┤
│   Process   │  FFmpegKit  │    Custom       │
│  (Desktop)  │  (Mobile)   │ (Your impl)     │
└─────────────┴─────────────┴─────────────────┘
```

This allows:
- Desktop: Direct FFmpeg process execution
- Mobile: FFmpegKit integration
- Custom: Server-based encoding, WASM, etc.

---

## FFmpegProvider Interface

### Interface Definition

```dart
abstract class FFmpegProvider {
  /// Check if FFmpeg is available
  Future<bool> isAvailable();

  /// Get FFmpeg version string
  Future<String> getVersion();

  /// Execute an FFmpeg command
  /// Returns exit code (0 = success)
  Future<int> execute(List<String> arguments);

  /// Execute with progress callback
  Future<int> executeWithProgress(
    List<String> arguments, {
    void Function(double progress)? onProgress,
    void Function(String line)? onOutput,
  });

  /// Cancel any running execution
  Future<void> cancel();

  /// Probe a media file for metadata
  Future<MediaInfo?> probe(String filePath);
}

class MediaInfo {
  final Duration duration;
  final int width;
  final int height;
  final double fps;
  final String? videoCodec;
  final String? audioCodec;
  final int? bitrate;

  const MediaInfo({
    required this.duration,
    required this.width,
    required this.height,
    required this.fps,
    this.videoCodec,
    this.audioCodec,
    this.bitrate,
  });
}
```

---

## ProcessFFmpegProvider

The default desktop implementation uses Dart's `Process` API:

```dart
class ProcessFFmpegProvider implements FFmpegProvider {
  final String ffmpegPath;
  final String ffprobePath;
  Process? _currentProcess;

  ProcessFFmpegProvider({
    this.ffmpegPath = 'ffmpeg',
    this.ffprobePath = 'ffprobe',
  });

  @override
  Future<bool> isAvailable() async {
    try {
      final result = await Process.run(ffmpegPath, ['-version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String> getVersion() async {
    final result = await Process.run(ffmpegPath, ['-version']);
    final output = result.stdout as String;
    // Parse version from first line
    final match = RegExp(r'ffmpeg version (\S+)').firstMatch(output);
    return match?.group(1) ?? 'unknown';
  }

  @override
  Future<int> execute(List<String> arguments) async {
    _currentProcess = await Process.start(ffmpegPath, arguments);
    return await _currentProcess!.exitCode;
  }

  @override
  Future<int> executeWithProgress(
    List<String> arguments, {
    void Function(double progress)? onProgress,
    void Function(String line)? onOutput,
  }) async {
    // Add progress output
    final args = ['-progress', 'pipe:1', '-y', ...arguments];

    _currentProcess = await Process.start(ffmpegPath, args);

    // Parse progress from stdout
    _currentProcess!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      onOutput?.call(line);

      // Parse progress
      if (line.startsWith('out_time_ms=')) {
        final ms = int.tryParse(line.split('=')[1]) ?? 0;
        // Calculate progress based on expected duration
        // (This is simplified - real implementation needs total duration)
        onProgress?.call(ms / 1000000);  // Convert to seconds
      }
    });

    _currentProcess!.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      onOutput?.call(line);
    });

    return await _currentProcess!.exitCode;
  }

  @override
  Future<void> cancel() async {
    _currentProcess?.kill(ProcessSignal.sigterm);
    _currentProcess = null;
  }

  @override
  Future<MediaInfo?> probe(String filePath) async {
    final result = await Process.run(ffprobePath, [
      '-v', 'quiet',
      '-print_format', 'json',
      '-show_format',
      '-show_streams',
      filePath,
    ]);

    if (result.exitCode != 0) return null;

    final json = jsonDecode(result.stdout as String);
    // Parse MediaInfo from JSON
    return _parseMediaInfo(json);
  }

  MediaInfo _parseMediaInfo(Map<String, dynamic> json) {
    final streams = json['streams'] as List;
    final videoStream = streams.firstWhere(
      (s) => s['codec_type'] == 'video',
      orElse: () => null,
    );
    final audioStream = streams.firstWhere(
      (s) => s['codec_type'] == 'audio',
      orElse: () => null,
    );
    final format = json['format'] as Map<String, dynamic>?;

    // Parse frame rate
    final fpsStr = videoStream?['r_frame_rate'] as String? ?? '30/1';
    final fpsParts = fpsStr.split('/');
    final fps = int.parse(fpsParts[0]) / int.parse(fpsParts[1]);

    return MediaInfo(
      duration: Duration(
        microseconds: (double.parse(format?['duration'] ?? '0') * 1000000).round(),
      ),
      width: videoStream?['width'] ?? 0,
      height: videoStream?['height'] ?? 0,
      fps: fps,
      videoCodec: videoStream?['codec_name'],
      audioCodec: audioStream?['codec_name'],
      bitrate: int.tryParse(format?['bit_rate'] ?? ''),
    );
  }
}
```

---

## Mobile FFmpegKit

For mobile platforms, use FFmpegKit:

```dart
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';

class FFmpegKitProvider implements FFmpegProvider {
  @override
  Future<bool> isAvailable() async {
    // FFmpegKit is always available when the package is included
    return true;
  }

  @override
  Future<String> getVersion() async {
    final info = await FFmpegKitConfig.getFFmpegVersion();
    return info ?? 'unknown';
  }

  @override
  Future<int> execute(List<String> arguments) async {
    final command = arguments.join(' ');
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();
    return ReturnCode.isSuccess(returnCode) ? 0 : 1;
  }

  @override
  Future<int> executeWithProgress(
    List<String> arguments, {
    void Function(double progress)? onProgress,
    void Function(String line)? onOutput,
  }) async {
    final command = arguments.join(' ');

    final session = await FFmpegKit.executeAsync(
      command,
      (session) async {
        // Completion callback
      },
      (log) {
        // Log callback
        onOutput?.call(log.getMessage());
      },
      (statistics) {
        // Statistics callback
        final time = statistics.getTime();
        if (time > 0) {
          // Calculate progress (need to know total duration)
          onProgress?.call(time / 1000);  // time is in ms
        }
      },
    );

    // Wait for completion
    await session.getReturnCode();
    final returnCode = await session.getReturnCode();
    return ReturnCode.isSuccess(returnCode) ? 0 : 1;
  }

  @override
  Future<void> cancel() async {
    await FFmpegKit.cancel();
  }

  @override
  Future<MediaInfo?> probe(String filePath) async {
    final session = await FFprobeKit.getMediaInformation(filePath);
    final info = session.getMediaInformation();

    if (info == null) return null;

    final streams = info.getStreams();
    final videoStream = streams?.firstWhere(
      (s) => s.getType() == 'video',
      orElse: () => null,
    );

    return MediaInfo(
      duration: Duration(
        milliseconds: (info.getDuration() ?? 0).toInt(),
      ),
      width: videoStream?.getWidth() ?? 0,
      height: videoStream?.getHeight() ?? 0,
      fps: _parseFps(videoStream?.getRealFrameRate()),
      videoCodec: videoStream?.getCodec(),
      audioCodec: streams?.firstWhere(
        (s) => s.getType() == 'audio',
        orElse: () => null,
      )?.getCodec(),
      bitrate: int.tryParse(info.getBitrate() ?? ''),
    );
  }

  double _parseFps(String? fpsStr) {
    if (fpsStr == null) return 30.0;
    final parts = fpsStr.split('/');
    if (parts.length != 2) return 30.0;
    return int.parse(parts[0]) / int.parse(parts[1]);
  }
}
```

### pubspec.yaml for Mobile

```yaml
dependencies:
  ffmpeg_kit_flutter: ^6.0.0
  # Or specific package for features needed:
  # ffmpeg_kit_flutter_full: ^6.0.0      # All codecs
  # ffmpeg_kit_flutter_min: ^6.0.0       # Minimal
```

---

## Custom Implementation

### Server-Based Provider

For cloud/server encoding:

```dart
class ServerFFmpegProvider implements FFmpegProvider {
  final String serverUrl;
  final http.Client _client;
  String? _currentJobId;

  ServerFFmpegProvider({
    required this.serverUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  Future<bool> isAvailable() async {
    try {
      final response = await _client.get(
        Uri.parse('$serverUrl/health'),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<int> execute(List<String> arguments) async {
    return executeWithProgress(arguments);
  }

  @override
  Future<int> executeWithProgress(
    List<String> arguments, {
    void Function(double progress)? onProgress,
    void Function(String line)? onOutput,
  }) async {
    // Upload frames/assets first
    final uploadedFiles = await _uploadAssets(arguments);

    // Start job
    final response = await _client.post(
      Uri.parse('$serverUrl/jobs'),
      body: jsonEncode({
        'arguments': _remapPaths(arguments, uploadedFiles),
      }),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 201) {
      return 1;
    }

    final job = jsonDecode(response.body);
    _currentJobId = job['id'];

    // Poll for progress
    while (true) {
      final statusResponse = await _client.get(
        Uri.parse('$serverUrl/jobs/$_currentJobId'),
      );

      final status = jsonDecode(statusResponse.body);

      if (status['progress'] != null) {
        onProgress?.call(status['progress'] as double);
      }

      if (status['status'] == 'completed') {
        // Download result
        await _downloadResult(status['outputUrl']);
        return 0;
      } else if (status['status'] == 'failed') {
        onOutput?.call('Job failed: ${status['error']}');
        return 1;
      }

      await Future.delayed(const Duration(seconds: 1));
    }
  }

  @override
  Future<void> cancel() async {
    if (_currentJobId != null) {
      await _client.delete(
        Uri.parse('$serverUrl/jobs/$_currentJobId'),
      );
      _currentJobId = null;
    }
  }

  @override
  Future<MediaInfo?> probe(String filePath) async {
    // Upload file and probe on server
    final uploadUrl = await _uploadFile(filePath);

    final response = await _client.post(
      Uri.parse('$serverUrl/probe'),
      body: jsonEncode({'url': uploadUrl}),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body);
    return MediaInfo(
      duration: Duration(milliseconds: data['duration']),
      width: data['width'],
      height: data['height'],
      fps: data['fps'],
      videoCodec: data['videoCodec'],
      audioCodec: data['audioCodec'],
      bitrate: data['bitrate'],
    );
  }

  Future<Map<String, String>> _uploadAssets(List<String> arguments) async {
    // Implementation: upload local files to server
    throw UnimplementedError();
  }

  List<String> _remapPaths(
    List<String> arguments,
    Map<String, String> uploadedFiles,
  ) {
    // Replace local paths with server URLs
    throw UnimplementedError();
  }

  Future<void> _downloadResult(String url) async {
    // Download encoded video from server
    throw UnimplementedError();
  }

  Future<String> _uploadFile(String path) async {
    // Upload single file
    throw UnimplementedError();
  }
}
```

### WASM Provider (Web)

For browser-based encoding using FFmpeg.wasm:

```dart
@JS()
library ffmpeg_wasm;

import 'package:js/js.dart';

@JS('FFmpeg')
class FFmpegWasm {
  external FFmpegWasm();
  external Promise<void> load();
  external Promise<void> run(List<String> args);
  external void writeFile(String name, Uint8List data);
  external Uint8List readFile(String name);
}

class WasmFFmpegProvider implements FFmpegProvider {
  final FFmpegWasm _ffmpeg = FFmpegWasm();
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (!_loaded) {
      await promiseToFuture(_ffmpeg.load());
      _loaded = true;
    }
  }

  @override
  Future<bool> isAvailable() async {
    try {
      await _ensureLoaded();
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<int> execute(List<String> arguments) async {
    await _ensureLoaded();

    try {
      await promiseToFuture(_ffmpeg.run(arguments));
      return 0;
    } catch (e) {
      return 1;
    }
  }

  // ... other methods
}
```

---

## Testing Providers

### Mock Provider for Testing

```dart
class MockFFmpegProvider implements FFmpegProvider {
  final List<List<String>> executedCommands = [];
  int nextExitCode = 0;
  MediaInfo? mockMediaInfo;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<String> getVersion() async => '5.0.0';

  @override
  Future<int> execute(List<String> arguments) async {
    executedCommands.add(arguments);
    return nextExitCode;
  }

  @override
  Future<int> executeWithProgress(
    List<String> arguments, {
    void Function(double progress)? onProgress,
    void Function(String line)? onOutput,
  }) async {
    executedCommands.add(arguments);

    // Simulate progress
    for (var i = 0; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 10));
      onProgress?.call(i / 10);
    }

    return nextExitCode;
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<MediaInfo?> probe(String filePath) async => mockMediaInfo;
}
```

### Testing with Mock

```dart
void main() {
  group('RenderService', () {
    late MockFFmpegProvider mockProvider;

    setUp(() {
      mockProvider = MockFFmpegProvider();
      FFmpegProviderRegistry.setProvider(mockProvider);
    });

    test('executes correct FFmpeg command', () async {
      await RenderService.execute(
        composition: testVideo,
        outputPath: 'output.mp4',
      );

      expect(mockProvider.executedCommands, isNotEmpty);

      final command = mockProvider.executedCommands.first;
      expect(command, contains('-r'));
      expect(command, contains('30'));  // fps
      expect(command, contains('output.mp4'));
    });

    test('handles FFmpeg failure', () async {
      mockProvider.nextExitCode = 1;

      expect(
        () => RenderService.execute(
          composition: testVideo,
          outputPath: 'output.mp4',
        ),
        throwsA(isA<EncodingException>()),
      );
    });
  });
}
```

---

## Provider Registration

### Global Provider

```dart
class FFmpegProviderRegistry {
  static FFmpegProvider? _provider;

  static FFmpegProvider get provider {
    return _provider ?? _defaultProvider();
  }

  static void setProvider(FFmpegProvider provider) {
    _provider = provider;
  }

  static FFmpegProvider _defaultProvider() {
    if (kIsWeb) {
      return WasmFFmpegProvider();
    } else if (Platform.isAndroid || Platform.isIOS) {
      return FFmpegKitProvider();
    } else {
      return ProcessFFmpegProvider();
    }
  }
}
```

### Usage in RenderService

```dart
class RenderService {
  static Future<void> execute({
    required Video composition,
    required String outputPath,
    FFmpegProvider? ffmpegProvider,
  }) async {
    final provider = ffmpegProvider ?? FFmpegProviderRegistry.provider;

    // Check availability
    if (!await provider.isAvailable()) {
      throw FFmpegNotAvailableException();
    }

    // Build command
    final arguments = _buildCommand(composition, outputPath);

    // Execute
    final exitCode = await provider.execute(arguments);

    if (exitCode != 0) {
      throw EncodingException('FFmpeg exited with code $exitCode');
    }
  }
}
```

---

## Related

- [Encoding Settings](../advanced/encoding-settings.md) - Quality settings
- [Custom Render Pipeline](../advanced/custom-render-pipeline.md) - Rendering customization
- [Server Mode](../ONLY_SERVER_MODE.md) - Server-based rendering
- [Platform Setup](../platform-setup/overview.md) - Platform installation

